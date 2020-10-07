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

	associatedtype ResourceList: KubernetesResourceList where ResourceList.Item: KubernetesAPIResource

	var httpClient: HTTPClient { get }
	var config: KubernetesClientConfig { get }

	init(httpClient: HTTPClient, config: KubernetesClientConfig, logger: Logger?)
}

public class GenericKubernetesClient<ResourceList: KubernetesResourceList>: KubernetesAPIResourceClient
	where ResourceList.Item: KubernetesAPIResource {

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let gvk: GroupVersionKind
	public let apiVersion: APIVersion

	private let logger: Logger

	public required init(httpClient: HTTPClient, config: KubernetesClientConfig, logger: Logger? = nil) {
		self.httpClient = httpClient
		self.config = config
		self.gvk = GroupVersionKind(of: ResourceList.Item.self)!
		self.apiVersion = ResourceList.Item.apiVersion
		self.logger = logger ?? KubernetesClient.loggingDisabled
	}

	private func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
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

	public func list(in namespace: NamespaceSelector, selector: ListSelector? = nil) -> EventLoopFuture<ResourceList> {
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

	public func get(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<ResourceList.Item> {
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

	public func create(in namespace: NamespaceSelector, _ resource: ResourceList.Item) -> EventLoopFuture<ResourceList.Item> {
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

	public func delete(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<ResourceOrStatus<ResourceList.Item>> {
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
}

extension GenericKubernetesClient where ResourceList.Item: ResourceWithMetadata {

	public func update(in namespace: NamespaceSelector, _ resource: ResourceList.Item) -> EventLoopFuture<ResourceList.Item> {
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

public class NamespacedGenericKubernetesClient<ResourceList: KubernetesResourceList>: GenericKubernetesClient<ResourceList> where ResourceList.Item: KubernetesAPIResource {

	public override func list(in namespace: NamespaceSelector? = nil, selector: ListSelector? = nil) -> EventLoopFuture<ResourceList> {
		return super.list(in: namespace ?? .namespace(self.config.namespace) , selector: selector)
	}

	public override func get(in namespace: NamespaceSelector? = nil, name: String) -> EventLoopFuture<ResourceList.Item> {
		return super.get(in: namespace ?? .namespace(self.config.namespace), name: name)
	}

	public func create(inNamespace namespace: String? = nil, _ resource: ResourceList.Item) -> EventLoopFuture<ResourceList.Item> {
		return super.create(in: .namespace(namespace ?? self.config.namespace), resource)
	}

	public func create(inNamespace namespace: String? = nil, _ block: () -> ResourceList.Item) -> EventLoopFuture<ResourceList.Item> {
		return super.create(in: .namespace(namespace ?? self.config.namespace), block())
	}

	public func update<R: ResourceWithMetadata>(inNamespace namespace: String? = nil, _ resource: R) -> EventLoopFuture<R> where R == ResourceList.Item {
		return super.update(in: .namespace(namespace ?? self.config.namespace), resource)
	}

	public func delete(inNamespace namespace: String? = nil, name: String) -> EventLoopFuture<ResourceOrStatus<ResourceList.Item>> {
		return super.delete(in: .namespace(namespace ?? self.config.namespace), name: name)
	}

	public func watch(in namespace: NamespaceSelector? = nil, eventHandler: @escaping ResourceWatch<ResourceList.Item>.EventHandler) -> EventLoopFuture<Void> {
		return super.watch(in: namespace ?? NamespaceSelector.allNamespaces, watch: ResourceWatch<ResourceList.Item>(eventHandler))
	}
}

public class ClusterScopedGenericKubernetesClient<ResourceList: KubernetesResourceList>: GenericKubernetesClient<ResourceList> where ResourceList.Item: KubernetesAPIResource {

	public func list(selector: ListSelector? = nil) -> EventLoopFuture<ResourceList> {
		return super.list(in: .allNamespaces, selector: selector)
	}

	public func get(name: String) -> EventLoopFuture<ResourceList.Item> {
		return super.get(in: .allNamespaces, name: name)
	}

	public func create(_ resource: ResourceList.Item) -> EventLoopFuture<ResourceList.Item> {
		return super.create(in: .allNamespaces, resource)
	}

	public func create(_ block: () -> ResourceList.Item) -> EventLoopFuture<ResourceList.Item> {
		return super.create(in: .allNamespaces, block())
	}

	public func delete(name: String) -> EventLoopFuture<ResourceOrStatus<ResourceList.Item>> {
		return super.delete(in: .allNamespaces, name: name)
	}

	public func watch(eventHandler: @escaping ResourceWatch<ResourceList.Item>.EventHandler) -> EventLoopFuture<Void> {
		return super.watch(in: .allNamespaces, watch: ResourceWatch<ResourceList.Item>(eventHandler))
	}
}

extension GenericKubernetesClient {

	internal func watch(in namespace: NamespaceSelector, watch: ResourceWatch<ResourceList.Item>) -> EventLoopFuture<Void> {
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

			return self.httpClient.execute(request: request, delegate: WatchDelegate(watch: watch), logger: logger).futureResult
		} catch let error {
			return eventLoop.makeFailedFuture(error)
		}
	}
}
