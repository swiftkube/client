//
// Copyright 2020 Swiftkube Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import AsyncHTTPClient
import Foundation
import Logging
import NIO
import SwiftkubeModel

// MARK: - Info

public struct Info: Codable {
	public let major: String
	public let minor: String
	public let gitVersion: String
	public let gitCommit: String
	public let gitTreeState: String
	public let buildDate: String
	public let goVersion: String
	public let compiler: String
	public let platform: String
}

// MARK: - DiscoveryAPI

public protocol DiscoveryAPI {
	func serverVersion() -> EventLoopFuture<ResourceOrStatus<Info>>
	func serverGroups() -> EventLoopFuture<ResourceOrStatus<meta.v1.APIGroupList>>
	func serverResources(forGroupVersion groupVersion: String) -> EventLoopFuture<ResourceOrStatus<meta.v1.APIResourceList>>
}

// MARK: - KubernetesClient

public extension KubernetesClient {

	var discoveryClient: DiscoveryAPI {
		DiscoveryClient(httpClient: httpClient, config: config, jsonDecoder: jsonDecoder, logger: logger)
	}
}

// MARK: - DiscoveryClient

internal class DiscoveryClient: DiscoveryAPI {

	private let httpClient: HTTPClient
	private let config: KubernetesClientConfig
	private let jsonDecoder: JSONDecoder
	private let logger: Logger

	init(httpClient: HTTPClient, config: KubernetesClientConfig, jsonDecoder: JSONDecoder, logger: Logger) {
		self.httpClient = httpClient
		self.config = config
		self.jsonDecoder = jsonDecoder
		self.logger = logger
	}

	func serverVersion() -> EventLoopFuture<ResourceOrStatus<Info>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().path("/version").build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	func serverGroups() -> EventLoopFuture<ResourceOrStatus<meta.v1.APIGroupList>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let legacyAPIVersionsRequest = try makeRequest().path("/api").build()
			let apiGroupListRequest = try makeRequest().path("/apis").build()

			let apiVersions: EventLoopFuture<ResourceOrStatus<meta.v1.APIVersions>> = dispatch(request: legacyAPIVersionsRequest, eventLoop: eventLoop)
			let apiGroupList: EventLoopFuture<ResourceOrStatus<meta.v1.APIGroupList>> = dispatch(request: apiGroupListRequest, eventLoop: eventLoop)

			let legacyAPIGroup = apiVersions.map { result -> ResourceOrStatus<meta.v1.APIGroup> in
				switch result {
				case let .resource(apiVersions):
					let groupVersions = apiVersions.versions.map { version in meta.v1.GroupVersionForDiscovery(groupVersion: version, version: version) }
					let apiGroup = meta.v1.APIGroup(name: "", preferredVersion: groupVersions.first, serverAddressByClientCIDRs: nil, versions: groupVersions)
					return .resource(apiGroup)
				case let .status(status):
					return .status(status)
				}
			}

			return legacyAPIGroup.and(apiGroupList).map { coreGroup, groupList -> ResourceOrStatus<meta.v1.APIGroupList> in
				switch (coreGroup, groupList) {
				case let (.resource(lhs), .resource(rhs)):
					let allGroups = [lhs] + rhs.groups
					return .resource(meta.v1.APIGroupList(groups: allGroups))
				case let (.status(status), _):
					return .status(status)
				case let (_, .status(status)):
					return .status(status)
				}
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	func serverResources(forGroupVersion groupVersion: String) -> EventLoopFuture<ResourceOrStatus<meta.v1.APIResourceList>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()

			let path: String
			if groupVersion == "v1" {
				path = "/api/v1"
			} else {
				path = "/apis/\(groupVersion)"
			}

			let request = try makeRequest().path(path).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	func dispatch<T: Decodable>(request: HTTPClient.Request, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<T>> {
		let startTime = DispatchTime.now().uptimeNanoseconds

		return httpClient.execute(request: request, logger: logger)
			.always { (result: Result<HTTPClient.Response, Error>) in
				KubernetesClient.updateMetrics(startTime: startTime, request: request, result: result)
			}
			.flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
	}

	func handle<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<T>> {
		guard let byteBuffer = response.body else {
			return httpClient.eventLoopGroup.next().makeFailedFuture(SwiftkubeClientError.emptyResponse)
		}

		let data = Data(buffer: byteBuffer)

		if response.status.code >= 400 {
			guard let status = try? jsonDecoder.decode(meta.v1.Status.self, from: data) else {
				return eventLoop.makeFailedFuture(SwiftkubeClientError.decodingError("Error decoding meta.v1.Status"))
			}
			return eventLoop.makeFailedFuture(SwiftkubeClientError.requestError(status))
		}

		if let resource = try? jsonDecoder.decode(T.self, from: data) {
			return eventLoop.makeSucceededFuture(.resource(resource))
		} else if let status = try? jsonDecoder.decode(meta.v1.Status.self, from: data) {
			return eventLoop.makeSucceededFuture(.status(status))
		} else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.decodingError("Error decoding \(T.self)"))
		}
	}

	func makeRequest() -> DiscoveryRequestBuilder {
		DiscoveryRequestBuilder(config: config)
	}
}
