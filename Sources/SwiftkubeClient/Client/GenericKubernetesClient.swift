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
import NIOHTTP1
import NIOSSL
import SwiftkubeModel

/// Represens a response with a concrete `KubernetesAPIResource` or a `meta.v1.Status` object.
public enum ResourceOrStatus<T> {
	case resource(T)
	case status(meta.v1.Status)
}

/// A generic client implementation following the Kubernetes API style.
public class GenericKubernetesClient<Resource: KubernetesAPIResource> {

	public let gvk: GroupVersionKind

	internal let httpClient: HTTPClient
	internal let config: KubernetesClientConfig
	internal let logger: Logger
	internal let jsonDecoder: JSONDecoder

	internal var timeFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = .withInternetDateTime
		return formatter
	}()

	internal var microTimeFormatter: ISO8601DateFormatter = {
		let formatter = ISO8601DateFormatter()
		formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return formatter
	}()

	internal convenience init(httpClient: HTTPClient, config: KubernetesClientConfig, logger: Logger? = nil) {
		self.init(httpClient: httpClient, config: config, gvk: GroupVersionKind(of: Resource.self)!, logger: logger)
	}

	internal required init(httpClient: HTTPClient, config: KubernetesClientConfig, gvk: GroupVersionKind, logger: Logger? = nil) {
		self.httpClient = httpClient
		self.config = config
		self.gvk = gvk
		self.logger = logger ?? KubernetesClient.loggingDisabled
		self.jsonDecoder = JSONDecoder()
		jsonDecoder.dateDecodingStrategy = .custom { decoder -> Date in
			let string = try decoder.singleValueContainer().decode(String.self)

			if let date = self.timeFormatter.date(from: string) {
				return date
			}

			if let date = self.microTimeFormatter.date(from: string) {
				return date
			}

			let context = DecodingError.Context(
				codingPath: decoder.codingPath,
				debugDescription: "Expected date string to be either ISO8601 or ISO8601 with milliseconds."
			)
			throw DecodingError.dataCorrupted(context)
		}
	}

	public func get(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = self.httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.GET).resource(withName: name).in(namespace).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	public func create(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = self.httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.POST).resource(resource).in(namespace).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	public func update(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.PUT).resource(withName: resource.name).resource(resource).in(namespace).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	public func delete(in namespace: NamespaceSelector, name: String, options: meta.v1.DeleteOptions?) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.DELETE).resource(withName: name).in(namespace).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handleResourceOrStatus(response, eventLoop: eventLoop)
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	public func deleteAll(in namespace: NamespaceSelector) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.DELETE).in(namespace).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handleResourceOrStatus(response, eventLoop: eventLoop)
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

}

internal extension GenericKubernetesClient {

	func makeRequest() -> RequestBuilder<Resource> {
		return RequestBuilder(config: config, gvk: gvk)
	}

	func handle<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<T> {
		return handleResourceOrStatus(response, eventLoop: eventLoop).flatMap { (result: ResourceOrStatus<T>) -> EventLoopFuture<T> in
			guard case let ResourceOrStatus.resource(resource) = result else {
				return eventLoop.makeFailedFuture(SwiftkubeClientError.decodingError("Expected resource type in response but got meta.v1.Status instead"))
			}

			return eventLoop.makeSucceededFuture(resource)
		}
	}

	func handleResourceOrStatus<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<T>> {
		guard let byteBuffer = response.body else {
			return httpClient.eventLoopGroup.next().makeFailedFuture(SwiftkubeClientError.emptyResponse)
		}

		let data = Data(buffer: byteBuffer)
		jsonDecoder.userInfo[CodingUserInfoKey.apiVersion] = gvk.apiVersion
		jsonDecoder.userInfo[CodingUserInfoKey.kind] = gvk.kind

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
}

public extension GenericKubernetesClient where Resource: ListableResource {

	func list(in namespace: NamespaceSelector, options: [ListOption]? = nil) -> EventLoopFuture<Resource.List> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.GET).in(namespace).with(options: options).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

internal extension GenericKubernetesClient {

	func status(in namespace: NamespaceSelector, name: String) throws -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.GET).resource(withName: name).status().in(namespace).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	func updateStatus(in namespace: NamespaceSelector, _ resource: Resource) throws -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.PUT).resource(resource).status().in(namespace).build()

			return httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

internal extension GenericKubernetesClient {

	func watch(in namespace: NamespaceSelector, using watch: ResourceWatch<Resource>) throws -> HTTPClient.Task<Void> {
		let request = try makeRequest().toWatch().in(namespace).build()
		let delegate = WatchDelegate(watch: watch, logger: logger)

		return httpClient.execute(request: request, delegate: delegate, logger: logger)
	}

	func follow(in namespace: NamespaceSelector, name: String, container: String?, using watch: LogWatch) throws -> HTTPClient.Task<Void> {
		let request = try makeRequest().toFollow(pod: name, container: container).in(namespace).build()
		let delegate = WatchDelegate(watch: watch, logger: logger)

		return self.httpClient.execute(request: request, delegate: delegate, logger: logger)
	}
}
