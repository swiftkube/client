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
import SwiftkubeModel

private let logger = Logger(label: "swiftkube.client.ResourceHandler")

public struct ResourceHandlerContext {
	let apiGroupVersion: APIGroupVersion
	let resoucePluralName: String

	internal func urlPath(forNamespace namespace: NamespaceSelector) -> String {
		switch namespace {
		case .allNamespaces:
			return "\(apiGroupVersion.urlPath)/\(resoucePluralName)"
		case let .namespace(namespace):
			return "\(apiGroupVersion.urlPath)/namespaces/\(namespace)/\(resoucePluralName)"
		}
	}

	internal func urlPath(forNamespace namespace: NamespaceSelector, name: String) -> String {
		return "\(urlPath(forNamespace: namespace))/\(name)"
	}
}

public protocol BaseHandler {

	associatedtype ResourceList: KubernetesResourceList
	associatedtype Resource = KubernetesResource where Resource == ResourceList.Item

	var httpClient: HTTPClient { get }
	var config: KubernetesClientConfig { get }
	var context: ResourceHandlerContext { get }

	init(httpClient: HTTPClient, config: KubernetesClientConfig)
}

public enum ListSelector {
	case labelSelector([String: String])
	case fieldSelector([String: String])

	var name: String {
		switch self {
		case .labelSelector:
			return "labelSelector"
		case .fieldSelector:
			return "fieldSelector"
		}
	}

	var value: String {
		switch self {
		case let .labelSelector(labels):
			return labels.map { key, value in "\(key)=\(value)" }.joined(separator: ",")
		case let .fieldSelector(fields):
			return fields.map { key, value in "\(key)=\(value)" }.joined(separator: ",")
		}
	}
}

public enum NamespaceSelector {
	case namespace(String)
	case allNamespaces
}

public enum SwiftkubeAPIError: Error {
	case invalidURL
	case badRequest(String)
	case emptyResponse
	case decodingError(String)
	case requestError(meta.v1.Status)
}

public enum ResourceOrStatus<T> {
	case resource(T)
	case status(meta.v1.Status)
}

extension BaseHandler {

	private func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
		var headers: [(String, String)] = []
		if let authorizationHeader = authentication?.authorizationHeader() {
			headers.append(("Authorization", authorizationHeader))
		}

		return HTTPHeaders(headers)
	}

	private func handle<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<T> {
		return handleResourceOrStatus(response, eventLoop: eventLoop).flatMap { (result: ResourceOrStatus<T>) -> EventLoopFuture<T> in
			guard case let ResourceOrStatus.resource(resource) = result else {
				return eventLoop.makeFailedFuture(SwiftkubeAPIError.decodingError("Expected resource type in response but got meta.v1.Status instead"))
			}

			return eventLoop.makeSucceededFuture(resource)
		}
	}

	private func handleResourceOrStatus<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<T>> {
		logger.debug("Got response: \(response)")
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

	internal func _list(in namespace: NamespaceSelector, selector: ListSelector? = nil) -> EventLoopFuture<ResourceList> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = context.urlPath(forNamespace: namespace)

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

	internal func _get(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = context.urlPath(forNamespace: namespace, name: name)

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

	internal func _create(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = context.urlPath(forNamespace: namespace)

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

	internal func _delete(in namespace: NamespaceSelector, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = context.urlPath(forNamespace: namespace, name: name)

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

extension BaseHandler where Resource: ResourceWithMetadata {

	internal func _update(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		guard let name = resource.name else {
			return eventLoop.makeFailedFuture(SwiftkubeAPIError.badRequest("Resource metadata.name must be set for \(resource)"))
		}
		components?.path = context.urlPath(forNamespace: namespace, name: name)

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

extension BaseHandler {

	internal func watch(in namespace: NamespaceSelector, watch: ResourceWatch<Resource>) -> EventLoopFuture<Void> {
		let eventLoop = self.httpClient.eventLoopGroup.next()
		var components = URLComponents(url: self.config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = context.urlPath(forNamespace: namespace)
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
