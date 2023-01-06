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
	func serverVersion() async throws -> Info
	func serverGroups() async throws -> meta.v1.APIGroupList
	func serverResources() async throws -> [meta.v1.APIResourceList]
	func serverResources(forGroupVersion groupVersion: String) async throws -> meta.v1.APIResourceList
}

// MARK: - KubernetesClient

public extension KubernetesClient {

	var discoveryClient: DiscoveryAPI {
		DiscoveryClient(httpClient: httpClient, config: config, jsonDecoder: jsonDecoder, logger: logger)
	}
}

// MARK: - DiscoveryClient

internal class DiscoveryClient: DiscoveryAPI, RequestHandlerType {

	internal let httpClient: HTTPClient
	internal let config: KubernetesClientConfig
	internal let jsonDecoder: JSONDecoder
	internal let logger: Logger

	init(httpClient: HTTPClient, config: KubernetesClientConfig, jsonDecoder: JSONDecoder, logger: Logger) {
		self.httpClient = httpClient
		self.config = config
		self.jsonDecoder = jsonDecoder
		self.logger = logger
	}

	func serverVersion() async throws -> Info {
		let request = try makeRequest().path("/version").build()
		return try await dispatch(request: request, expect: Info.self)
	}

	func serverGroups() async throws -> meta.v1.APIGroupList {
		let legacyAPIVersionsRequest = try makeRequest().path("/api").build()
		let apiGroupListRequest = try makeRequest().path("/apis").build()

		let apiVersions = try await dispatch(request: legacyAPIVersionsRequest, expect: meta.v1.APIVersions.self)
		let apiGroupList = try await dispatch(request: apiGroupListRequest, expect: meta.v1.APIGroupList.self)

		let groupVersions = apiVersions.versions.map { version in
			meta.v1.GroupVersionForDiscovery(groupVersion: version, version: version)
		}

		let legacyAPIGroup = meta.v1.APIGroup(
			name: "",
			preferredVersion: groupVersions.first,
			serverAddressByClientCIDRs: nil,
			versions: groupVersions
		)

		let allGroups = [legacyAPIGroup] + apiGroupList.groups
		return meta.v1.APIGroupList(groups: allGroups)
	}

	func serverResources() async throws -> [meta.v1.APIResourceList] {
		let groupList = try await serverGroups()

		var allResourceLists = [meta.v1.APIResourceList]()
		for version in groupList.groups.flatMap(\.versions) {
			let it = try await serverResources(forGroupVersion: version.groupVersion)
			allResourceLists.append(it)
		}

		let merged = allResourceLists.reduce(into: [meta.v1.APIResourceList]()) { (acc, other: meta.v1.APIResourceList) in
			acc.append(other)
		}

		return merged
	}

	func serverResources(forGroupVersion groupVersion: String) async throws -> meta.v1.APIResourceList {
		let path: String
		if groupVersion == "v1" {
			path = "/api/v1"
		} else {
			path = "/apis/\(groupVersion)"
		}

		let request = try makeRequest().path(path).build()

		return try await dispatch(request: request, expect: meta.v1.APIResourceList.self)
	}

	func makeRequest() -> DiscoveryRequestBuilder {
		DiscoveryRequestBuilder(config: config)
	}
}
