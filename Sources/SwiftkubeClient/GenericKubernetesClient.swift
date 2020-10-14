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

public enum ResourceOrStatus<T> {
	case resource(T)
	case status(meta.v1.Status)
}

public protocol KubernetesAPIResourceClient {

	associatedtype Resource: KubernetesAPIResource

	var httpClient: HTTPClient { get }
	var config: KubernetesClientConfig { get }

	init(httpClient: HTTPClient, config: KubernetesClientConfig, logger: Logger?)
}

public class GenericKubernetesClient<Resource: KubernetesAPIResource>: KubernetesAPIResourceClient {

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let gvk: GroupVersionKind
	public let apiVersion: APIVersion

	private let logger: Logger

	public required init(httpClient: HTTPClient, config: KubernetesClientConfig, logger: Logger? = nil) {
		self.httpClient = httpClient
		self.config = config
		self.gvk = GroupVersionKind(of: Resource.self)!
		self.apiVersion = Resource.apiVersion
		self.logger = logger ?? KubernetesClient.loggingDisabled
	}

	internal func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
		var headers: [(String, String)] = []
		if let authorizationHeader = authentication?.authorizationHeader() {
			headers.append(("Authorization", authorizationHeader))
		}

		return HTTPHeaders(headers)
	}

	internal func handle<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<T> {
		return handleResourceOrStatus(response, eventLoop: eventLoop).flatMap { (result: ResourceOrStatus<T>) -> EventLoopFuture<T> in
			guard case let ResourceOrStatus.resource(resource) = result else {
				return eventLoop.makeFailedFuture(SwiftkubeAPIError.decodingError("Expected resource type in response but got meta.v1.Status instead"))
			}

			return eventLoop.makeSucceededFuture(resource)
		}
	}

	internal func handleResourceOrStatus<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<T>> {
		guard let byteBuffer = response.body else {
			return self.httpClient.eventLoopGroup.next().makeFailedFuture(SwiftkubeAPIError.emptyResponse)
		}

		let data = Data(buffer: byteBuffer)

		if response.status.code >= 400 {
			guard let status = try? JSONDecoder().decode(meta.v1.Status.self, from: data) else {
				return eventLoop.makeFailedFuture(SwiftkubeAPIError.decodingError("Error decoding meta.v1.Status"))
			}
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.requestError(status))
		}

		if let resource = try? JSONDecoder().decode(T.self, from: data) {
			return eventLoop.makeSucceededFuture(.resource(resource))
		} else if let status = try? JSONDecoder().decode(meta.v1.Status.self, from: data) {
			return eventLoop.makeSucceededFuture(.status(status))
		} else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.decodingError("Error decoding \(T.self)"))
		}
	}

	internal func urlPath(forNamespace namespace: NamespaceSelector) -> String {
		switch namespace {
		case .allNamespaces:
			return "\(apiVersion.urlPath)/\(gvk.pluralName)"
		default:
			return "\(apiVersion.urlPath)/namespaces/\(namespace.namespaceName())/\(gvk.pluralName)"
		}
	}

	internal func urlPath(forNamespace namespace: NamespaceSelector, name: String) -> String {
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
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.invalidURL)
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

public extension GenericKubernetesClient where Resource: MetadataHavingResource {

	func get(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace, name: name)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.invalidURL)
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

	func create(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.invalidURL)
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

	func delete(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace, name: name)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.invalidURL)
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

	func update(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		guard let name = resource.name else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.badRequest("Resource metadata.name must be set for \(resource)"))
		}
		components?.path = urlPath(forNamespace: namespace, name: name)

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.invalidURL)
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
}

public class ClusterScopedGenericKubernetesClient<Resource: KubernetesAPIResource>: GenericKubernetesClient<Resource> {
}

public extension ClusterScopedGenericKubernetesClient where Resource: ListableResource {

	func list(selector: ListSelector? = nil) -> EventLoopFuture<Resource.List> {
		return super.list(in: .allNamespaces, selector: selector)
	}
}

public extension ClusterScopedGenericKubernetesClient where Resource: MetadataHavingResource {

	func get(name: String) -> EventLoopFuture<Resource> {
		return super.get(in: .allNamespaces, name: name)
	}

	func create(_ resource: Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .allNamespaces, resource)
	}

	func create(_ block: () -> Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .allNamespaces, block())
	}

	func delete(name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return super.delete(in: .allNamespaces, name: name)
	}

	func watch(eventHandler: @escaping ResourceWatch<Resource>.EventHandler) -> EventLoopFuture<Void> {
		return super.watch(in: .allNamespaces, watch: ResourceWatch<Resource>(eventHandler))
	}
}

public class NamespacedGenericKubernetesClient<Resource: KubernetesAPIResource>: GenericKubernetesClient<Resource> {}

public extension NamespacedGenericKubernetesClient where Resource: ListableResource {

	func list(in namespace: NamespaceSelector? = nil, selector: ListSelector? = nil) -> EventLoopFuture<Resource.List> {
		return super.list(in: namespace ?? .namespace(self.config.namespace) , selector: selector)
	}
}

public extension NamespacedGenericKubernetesClient where Resource: MetadataHavingResource {

	func get(in namespace: NamespaceSelector? = nil, name: String) -> EventLoopFuture<Resource> {
		return super.get(in: namespace ?? .namespace(self.config.namespace), name: name)
	}

	func create(inNamespace namespace: String? = nil, _ resource: Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .namespace(namespace ?? self.config.namespace), resource)
	}

	func create(inNamespace namespace: String? = nil, _ block: () -> Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .namespace(namespace ?? self.config.namespace), block())
	}

	func update(inNamespace namespace: String? = nil, _ resource: Resource) -> EventLoopFuture<Resource> {
		return super.update(in: .namespace(namespace ?? self.config.namespace), resource)
	}

	func delete(inNamespace namespace: String? = nil, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return super.delete(in: .namespace(namespace ?? self.config.namespace), name: name)
	}

	func watch(in namespace: NamespaceSelector? = nil, eventHandler: @escaping ResourceWatch<Resource>.EventHandler) -> EventLoopFuture<Void> {
		return super.watch(in: namespace ?? NamespaceSelector.allNamespaces, watch: ResourceWatch<Resource>(eventHandler))
	}
}

extension GenericKubernetesClient {

	internal func watch(in namespace: NamespaceSelector, watch: ResourceWatch<Resource>) -> EventLoopFuture<Void> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace)
		components?.queryItems = [
			URLQueryItem(name: "watch", value: "true")
		]

		guard let url = components?.url?.absoluteString else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.invalidURL)
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
}
