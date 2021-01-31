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
import Metrics
import NIO
import NIOHTTP1
import NIOSSL
import SwiftkubeModel

// MARK: - ResourceOrStatus

/// Represens a response with a concrete `KubernetesAPIResource` or a `meta.v1.Status` object.
public enum ResourceOrStatus<T> {
	case resource(T)
	case status(meta.v1.Status)
}

// MARK: - GenericKubernetesClient

/// A generic client implementation following the Kubernetes API style.
public class GenericKubernetesClient<Resource: KubernetesAPIResource> {

	public let gvk: GroupVersionKind

	internal let httpClient: HTTPClient
	internal let config: KubernetesClientConfig
	internal let logger: Logger

	internal let jsonDecoder: JSONDecoder = {
		let timeFormatter: ISO8601DateFormatter = {
			let formatter = ISO8601DateFormatter()
			formatter.formatOptions = .withInternetDateTime
			return formatter
		}()

		let microTimeFormatter: ISO8601DateFormatter = {
			let formatter = ISO8601DateFormatter()
			formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
			return formatter
		}()

		let jsonDecoder = JSONDecoder()
		jsonDecoder.dateDecodingStrategy = .custom { decoder -> Date in
			let string = try decoder.singleValueContainer().decode(String.self)

			if let date = timeFormatter.date(from: string) {
				return date
			}

			if let date = microTimeFormatter.date(from: string) {
				return date
			}

			let context = DecodingError.Context(
				codingPath: decoder.codingPath,
				debugDescription: "Expected date string to be either ISO8601 or ISO8601 with milliseconds."
			)
			throw DecodingError.dataCorrupted(context)
		}

		return jsonDecoder
	}()

	/// Create a new instance of the generic client.
	///
	/// The `GroupVersionKind` of this client instance will be inferred by the generic constraint.
	///
	/// ```swift
	/// let client = GenericKubernetesClient<core.v1.Deployment>(httpClient: client, config: config)
	/// ```
	///
	/// - Parameters:
	///   - httpClient: An instance of Async HTTPClient.
	///   - config: The configuration for this client instance.
	///   - logger: The logger to use for this client.
	internal convenience init(httpClient: HTTPClient, config: KubernetesClientConfig, logger: Logger? = nil) {
		self.init(httpClient: httpClient, config: config, gvk: GroupVersionKind(of: Resource.self)!, logger: logger)
	}

	/// Create a new instance of the generic client for the given `GroupVersionKind`.
	///
	/// - Parameters:
	///   - httpClient: An instance of Async HTTPClient.
	///   - config: The configuration for this client instance.
	///   - gvk: The `GroupVersionKind` of the target resource.
	///   - logger: The logger to use for this client.
	internal required init(httpClient: HTTPClient, config: KubernetesClientConfig, gvk: GroupVersionKind, logger: Logger? = nil) {
		self.httpClient = httpClient
		self.config = config
		self.gvk = gvk
		self.logger = logger ?? KubernetesClient.loggingDisabled
	}

	/// Loads an API resource by name in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the API resource to load.
	///
	/// - Returns: An `EventLoopFuture` holding the API resource specified by the given name in the given namespace.
	public func get(in namespace: NamespaceSelector, name: String, options: [ReadOption]? = nil) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.GET).resource(withName: name).in(namespace).with(options: options).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	/// Creates an API resource in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - resource: A `KubernetesAPIResource` instance to create.
	///
	/// - Returns: An `EventLoopFuture` holding the created `KubernetesAPIResource`.
	public func create(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.POST).resource(resource).in(namespace).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	/// Replaces, i.e. updates, an API resource with the given instance in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - resource: A `KubernetesAPIResource` instance to update.
	///
	/// - Returns: An `EventLoopFuture` holding the created `KubernetesAPIResource`.
	public func update(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.PUT).resource(withName: resource.name).resource(resource).in(namespace).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	/// Replaces, i.e. updates, an API resource with the given instance in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - resource: A `KubernetesAPIResource` instance to update.
	///
	/// - Returns: An `EventLoopFuture` holding the created `KubernetesAPIResource`.
	public func delete(in namespace: NamespaceSelector, name: String, options: meta.v1.DeleteOptions?) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.DELETE).resource(withName: name).in(namespace).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	/// Deletes all API resources in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// - Parameter namespace: The namespace for this API request.
	///
	/// - Returns: An `EventLoopFuture` holding a `ResourceOrStatus` instance.
	public func deleteAll(in namespace: NamespaceSelector) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.DELETE).in(namespace).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

public extension GenericKubernetesClient where Resource: ListableResource {

	/// Lists API resources in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - options: `ListOptions` instance to control the behaviour of the `List` operation.
	///
	/// - Returns: An `EventLoopFuture` holding a `KubernetesAPIResourceList` of resources.
	func list(in namespace: NamespaceSelector, options: [ListOption]? = nil) -> EventLoopFuture<Resource.List> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.GET).in(namespace).with(options: options).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

internal extension GenericKubernetesClient {

	func makeRequest() -> RequestBuilder<Resource> {
		RequestBuilder(config: config, gvk: gvk)
	}

	func dispatch<T: Decodable>(request: HTTPClient.Request, eventLoop: EventLoop) -> EventLoopFuture<T> {
		let startTime = DispatchTime.now().uptimeNanoseconds

		return httpClient.execute(request: request, logger: logger)
			.always { (result: Result<HTTPClient.Response, Error>) in
				self.updateMetrics(startTime: startTime, request: request, result: result)
			}
			.flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
	}

	func dispatch<T: Decodable>(request: HTTPClient.Request, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<T>> {
		let startTime = DispatchTime.now().uptimeNanoseconds

		return httpClient.execute(request: request, logger: logger)
			.always { (result: Result<HTTPClient.Response, Error>) in
				self.updateMetrics(startTime: startTime, request: request, result: result)
			}
			.flatMap { response in
				self.handleResourceOrStatus(response, eventLoop: eventLoop)
			}
	}

	func updateMetrics(startTime: UInt64, request: HTTPClient.Request, result: Result<HTTPClient.Response, Error>) {
		let method = request.method.rawValue
		let path = request.url.path

		switch result {
		case let .success(response):
			let statusCode = response.status.code
			let counterDimensions = [
				("method", method),
				("path", path),
				("status", statusCode.description),
			]

			Counter(label: "sk_http_requests_total", dimensions: counterDimensions).increment()
			if statusCode >= 500 {
				Counter(label: "sk_http_request_errors_total", dimensions: counterDimensions).increment()
			}
		case .failure:
			let counterDimensions = [
				("method", method),
				("path", path),
			]
			Counter(label: "sk_request_errors_total", dimensions: counterDimensions).increment()
		}

		Timer(
			label: "sk_http_request_duration_seconds",
			dimensions: [("method", method), ("path", path)],
			preferredDisplayUnit: .seconds
		)
		.recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
	}

	func handle<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<T> {
		handleResourceOrStatus(response, eventLoop: eventLoop).flatMap { (result: ResourceOrStatus<T>) -> EventLoopFuture<T> in
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

internal extension GenericKubernetesClient {

	func status(in namespace: NamespaceSelector, name: String) throws -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.GET).resource(withName: name).status().in(namespace).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	func updateStatus(in namespace: NamespaceSelector, _ resource: Resource) throws -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().to(.PUT).resource(resource).status().in(namespace).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

internal extension GenericKubernetesClient {

	/// Watches the API resources in the given namespace.
	///
	/// Watching resources opens a persistent connection to the API server. The connection is represented by a `HTTPClient.Task` instance, that acts
	/// as an active "subscription" to the events stream. The task can be cancelled any time to stop the watch.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// ```swift
	/// let task: HTTPClient.Task<Void> = client.pods.watch(in: .namespace("default")) { (event, pod) in
	///    print("\(event): \(pod)")
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - eventHandler: A `ResourceWatch.EventHandler` instance, which is used as a callback for new events. The client sends each
	/// event paired with the corresponding resource as a pair to the `eventHandler`.
	///
	/// - Returns: A cancellable `HTTPClient.Task` instance, representing a streaming connetion to the API server.
	func watch(in namespace: NamespaceSelector, options: [ListOption]? = nil, using watch: ResourceWatch<Resource>) throws -> HTTPClient.Task<Void> {
		let request = try makeRequest().toWatch().in(namespace).with(options: options).build()
		let delegate = WatchDelegate(watch: watch, logger: logger)

		return httpClient.execute(request: request, delegate: delegate, logger: logger)
	}

	/// Follows the logs of the specified container.
	///
	/// Following the logs of a container opens a persistent connection to the API server. The connection is represented by a `HTTPClient.Task` instance, that acts
	/// as an active "subscription" to the logs stream. The task can be cancelled any time to stop the watch.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// ```swift
	/// let task: HTTPClient.Task<Void> = client.pods.follow(in: .namespace("default"), name: "nginx") { line in
	///    print(line)
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the Pod.
	///   - container: The name of the container.
	///   - watch: A `LogWatch` instance, which is used as a callback for new log lines.
	///
	/// - Returns: A cancellable `HTTPClient.Task` instance, representing a streaming connetion to the API server.
	func follow(in namespace: NamespaceSelector, name: String, container: String?, using watch: LogWatch) throws -> HTTPClient.Task<Void> {
		let request = try makeRequest().toFollow(pod: name, container: container).in(namespace).build()
		let delegate = WatchDelegate(watch: watch, logger: logger)

		return httpClient.execute(request: request, delegate: delegate, logger: logger)
	}
}
