//
// Copyright 2020 Iskandar Abudiab (iabudiab.dev)
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

	public convenience init(httpClient: HTTPClient, config: KubernetesClientConfig, logger: Logger? = nil) {
		self.init(httpClient: httpClient, config: config, gvk: GroupVersionKind(of: Resource.self)!, logger: logger)
	}

	public required init(httpClient: HTTPClient, config: KubernetesClientConfig, gvk: GroupVersionKind, logger: Logger? = nil) {
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
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace, name: name)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.invalidURL)
		}

		do {
			let headers = buildHeaders(withAuthentication: config.authentication)
			let request = try HTTPClient.Request(url: url, method: .GET, headers: headers)

			return self.httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	public func create(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.invalidURL)
		}

		do {
			let data = try JSONEncoder().encode(resource)
			let headers = buildHeaders(withAuthentication: config.authentication)
			let request = try HTTPClient.Request(url: url, method: .POST, headers: headers, body: .data(data))

			return self.httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	public func update(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		guard let name = resource.name else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.badRequest("Resource metadata.name must be set for \(resource)"))
		}
		components?.path = urlPath(forNamespace: namespace, name: name)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.invalidURL)
		}

		do {
			let data = try JSONEncoder().encode(resource)
			let headers = buildHeaders(withAuthentication: config.authentication)
			let request = try HTTPClient.Request(url: url, method: .PUT, headers: headers, body: .data(data))

			return self.httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	public func delete(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace, name: name)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.invalidURL)
		}

		do {
			let headers = buildHeaders(withAuthentication: config.authentication)
			let request = try HTTPClient.Request(url: url, method: .DELETE, headers: headers)

			return self.httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handleResourceOrStatus(response, eventLoop: eventLoop)
			}
		} catch {
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

internal extension GenericKubernetesClient {

	func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
		var headers: [(String, String)] = []
		if let authorizationHeader = authentication?.authorizationHeader() {
			headers.append(("Authorization", authorizationHeader))
		}

		return HTTPHeaders(headers)
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
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(SwiftkubeClientError.emptyResponse)
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

	func urlPath(forNamespace namespace: NamespaceSelector) -> String {
		switch namespace {
		case .allNamespaces:
			return "\(gvk.urlPath)/\(gvk.pluralName)"
		default:
			return "\(gvk.urlPath)/namespaces/\(namespace.namespaceName())/\(gvk.pluralName)"
		}
	}

	func urlPath(forNamespace namespace: NamespaceSelector, name: String) -> String {
		return "\(urlPath(forNamespace: namespace))/\(name)"
	}
}

public extension GenericKubernetesClient where Resource: ListableResource {

	func list(in namespace: NamespaceSelector, selector: ListSelector? = nil) -> EventLoopFuture<Resource.List> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace)

		if let selector = selector {
			components?.queryItems = [URLQueryItem(name: selector.name, value: selector.value)]
		}

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.invalidURL)
		}

		do {
			let headers = buildHeaders(withAuthentication: config.authentication)
			let request = try HTTPClient.Request(url: url, method: .GET, headers: headers)

			return self.httpClient.execute(request: request, logger: logger).flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
		} catch {
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

public extension GenericKubernetesClient {

	internal func watch(in namespace: NamespaceSelector, watch: ResourceWatch<Resource>) -> EventLoopFuture<Void> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace)
		components?.queryItems = [
			URLQueryItem(name: "watch", value: "true")
		]

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.invalidURL)
		}

		do {
			let headers = buildHeaders(withAuthentication: config.authentication)
			let request = try HTTPClient.Request(url: url, method: .GET, headers: headers)
			let delegate = WatchDelegate(watch: watch, logger: logger)

			return self.httpClient.execute(request: request, delegate: delegate, logger: logger).futureResult
		} catch let error {
			return eventLoop.makeFailedFuture(error)
		}
	}

	internal func follow(in namespace: NamespaceSelector, name: String, container: String?, watch: LogWatch) throws -> HTTPClient.Task<Void> {
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace, name: name) + "/log"
		components?.queryItems = [
			URLQueryItem(name: "pretty", value: "true"),
			URLQueryItem(name: "follow", value: "true")
		]

		if let container = container {
			components?.queryItems?.append(URLQueryItem(name: "container", value: container))
		}

		guard let url = components?.url?.absoluteString else {
			throw SwiftkubeClientError.invalidURL
		}

		let headers = buildHeaders(withAuthentication: config.authentication)
		let request = try HTTPClient.Request(url: url, method: .GET, headers: headers)
		let delegate = WatchDelegate(watch: watch, logger: logger)

		return self.httpClient.execute(request: request, delegate: delegate, logger: logger)
	}
}

public class ClusterScopedGenericKubernetesClient<Resource: KubernetesAPIResource>: GenericKubernetesClient<Resource> {

	public func get(name: String) -> EventLoopFuture<Resource> {
		return super.get(in: .allNamespaces, name: name)
	}

	public func create(_ resource: Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .allNamespaces, resource)
	}

	public func create(_ block: () -> Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .allNamespaces, block())
	}

	public func delete(name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return super.delete(in: .allNamespaces, name: name)
	}

	public func watch(eventHandler: @escaping ResourceWatch<Resource>.EventHandler) -> EventLoopFuture<Void> {
		return super.watch(in: .allNamespaces, watch: ResourceWatch<Resource>(eventHandler))
	}
}

public extension ClusterScopedGenericKubernetesClient where Resource: ListableResource {

	func list(selector: ListSelector? = nil) -> EventLoopFuture<Resource.List> {
		return super.list(in: .allNamespaces, selector: selector)
	}
}

public class NamespacedGenericKubernetesClient<Resource: KubernetesAPIResource>: GenericKubernetesClient<Resource> {

	public override func get(in namespace: NamespaceSelector? = nil, name: String) -> EventLoopFuture<Resource> {
		return super.get(in: namespace ?? .namespace(self.config.namespace), name: name)
	}

	public func create(inNamespace namespace: NamespaceSelector? = nil, _ resource: Resource) -> EventLoopFuture<Resource> {
		return super.create(in: namespace ?? .namespace(config.namespace), resource)
	}

	public func create(inNamespace namespace: NamespaceSelector? = nil, _ block: () -> Resource) -> EventLoopFuture<Resource> {
		return super.create(in: namespace ?? .namespace(config.namespace), block())
	}

	public func update(inNamespace namespace: NamespaceSelector? = nil, _ resource: Resource) -> EventLoopFuture<Resource> {
		return super.update(in: namespace ?? .namespace(config.namespace), resource)
	}

	public func delete(inNamespace namespace: NamespaceSelector? = nil, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return super.delete(in: namespace ?? .namespace(config.namespace), name: name)
	}

	public func watch(in namespace: NamespaceSelector? = nil, eventHandler: @escaping ResourceWatch<Resource>.EventHandler) -> EventLoopFuture<Void> {
		return super.watch(in: namespace ?? NamespaceSelector.allNamespaces, watch: ResourceWatch<Resource>(logger: logger, eventHandler))
	}

	public func follow(in namespace: NamespaceSelector? = nil, name: String, container: String?, lineHandler: @escaping LogWatch.LineHandler) throws -> HTTPClient.Task<Void> {
		return try super.follow(in: namespace ?? NamespaceSelector.allNamespaces, name: name, container: container, watch: LogWatch(logger: logger, lineHandler))
	}
}

public extension NamespacedGenericKubernetesClient where Resource: ListableResource {

	func list(in namespace: NamespaceSelector? = nil, selector: ListSelector? = nil) -> EventLoopFuture<Resource.List> {
		return super.list(in: namespace ?? .namespace(self.config.namespace) , selector: selector)
	}
}
