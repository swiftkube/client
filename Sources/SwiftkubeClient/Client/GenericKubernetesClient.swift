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

	public let gvr: GroupVersionResource

	internal let httpClient: HTTPClient
	internal let config: KubernetesClientConfig
	internal let logger: Logger
	internal let jsonDecoder: JSONDecoder

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
	internal convenience init(httpClient: HTTPClient, config: KubernetesClientConfig, jsonDecoder: JSONDecoder, logger: Logger? = nil) {
		self.init(httpClient: httpClient, config: config, gvr: GroupVersionResource(of: Resource.self)!, jsonDecoder: jsonDecoder, logger: logger)
	}

	/// Create a new instance of the generic client for the given `GroupVersionKind`.
	///
	/// - Parameters:
	///   - httpClient: An instance of Async HTTPClient.
	///   - config: The configuration for this client instance.
	///   - gvr: The `GroupVersionResource` of the target resource.
	///   - logger: The logger to use for this client.
	internal required init(httpClient: HTTPClient, config: KubernetesClientConfig, gvr: GroupVersionResource, jsonDecoder: JSONDecoder, logger: Logger? = nil) {
		self.httpClient = httpClient
		self.config = config
		self.gvr = gvr
		self.jsonDecoder = jsonDecoder
		self.logger = logger ?? KubernetesClient.loggingDisabled
	}
}

// MARK: - GenericKubernetesClient

public extension GenericKubernetesClient {

	/// Loads an API resource by name in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the `KubernetesClientConfig` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the API resource to load.
	///
	/// - Returns: An `EventLoopFuture` holding the API resource specified by the given name in the given namespace.
	func get(in namespace: NamespaceSelector, name: String, options: [ReadOption]? = nil) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toGet().resource(withName: name).with(options: options).build()

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
	func create(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toPost().body(resource).build()

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
	func update(in namespace: NamespaceSelector, _ resource: Resource) -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toPut().resource(withName: resource.name).body(.resource(payload: resource)).build()

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
	func delete(in namespace: NamespaceSelector, name: String, options: meta.v1.DeleteOptions?) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toDelete().resource(withName: name).build()

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
	func deleteAll(in namespace: NamespaceSelector) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toDelete().build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

// MARK: - GenericKubernetesClient + ListableResource

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
			let request = try makeRequest().in(namespace).toGet().with(options: options).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

// MARK: - GenericKubernetesClient + ScalableResource

public extension GenericKubernetesClient where Resource: ScalableResource {

	/// Reads a resource's scale in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to load.
	///
	/// - Returns: An `EventLoopFuture` holding the `autoscaling.v1.Scale` for the desired resource .
	func getScale(in namespace: NamespaceSelector, name: String) throws -> EventLoopFuture<autoscaling.v1.Scale> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toGet().resource(withName: name).subResource(.scale).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	/// Replaces the resource's scale in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to update.
	///   - scale: An instance of `autoscaling.v1.Scale` to replace.
	///
	/// - Returns: An `EventLoopFuture` holding the updated `autoscaling.v1.Scale` for the desired resource .
	func updateScale(in namespace: NamespaceSelector, name: String, scale: autoscaling.v1.Scale) throws -> EventLoopFuture<autoscaling.v1.Scale> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toPut().resource(withName: name).body(.subResource(type: .scale, payload: scale)).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

// MARK: - GenericKubernetesClient - logs

internal extension GenericKubernetesClient {
	func logs(in namespace: NamespaceSelector, name: String) throws -> EventLoopFuture<String> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toGet().resource(withName: name).subResource(.log).build()

			return dispatchText(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

// MARK: - GenericKubernetesClient + StatusHavingResource

public extension GenericKubernetesClient where Resource: StatusHavingResource {

	/// Reads a resource's status in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to load.
	///
	/// - Returns: An `EventLoopFuture` holding the `KubernetesAPIResource`.
	func getStatus(in namespace: NamespaceSelector, name: String) throws -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toGet().resource(withName: name).subResource(.status).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}

	/// Replaces the resource's status in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to update.
	///   - resource: A `KubernetesAPIResource` instance to update.
	///
	/// - Returns: An `EventLoopFuture` holding the updated `KubernetesAPIResource`.
	func updateStatus(in namespace: NamespaceSelector, name: String, _ resource: Resource) throws -> EventLoopFuture<Resource> {
		do {
			let eventLoop = httpClient.eventLoopGroup.next()
			let request = try makeRequest().in(namespace).toPut().resource(withName: name).body(.subResource(type: .status, payload: resource)).build()

			return dispatch(request: request, eventLoop: eventLoop)
		} catch {
			return httpClient.eventLoopGroup.next().makeFailedFuture(error)
		}
	}
}

internal extension GenericKubernetesClient {

	func makeRequest() -> NamespaceStep {
		RequestBuilder(config: config, gvr: gvr)
	}

	func dispatch<T: Decodable>(request: HTTPClient.Request, eventLoop: EventLoop) -> EventLoopFuture<T> {
		let startTime = DispatchTime.now().uptimeNanoseconds

		return httpClient.execute(request: request, logger: logger)
			.always { (result: Result<HTTPClient.Response, Error>) in
				KubernetesClient.updateMetrics(startTime: startTime, request: request, result: result)
			}
			.flatMap { response in
				self.handle(response, eventLoop: eventLoop)
			}
	}

	func dispatchText(request: HTTPClient.Request, eventLoop: EventLoop) -> EventLoopFuture<String> {
		let startTime = DispatchTime.now().uptimeNanoseconds

		return httpClient.execute(request: request, logger: logger)
			.always { (result: Result<HTTPClient.Response, Error>) in
				KubernetesClient.updateMetrics(startTime: startTime, request: request, result: result)
			}
			.flatMap { response in
				self.handleText(response, eventLoop: eventLoop)
			}
	}

	func dispatch<T: Decodable>(request: HTTPClient.Request, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<T>> {
		let startTime = DispatchTime.now().uptimeNanoseconds

		return httpClient.execute(request: request, logger: logger)
			.always { (result: Result<HTTPClient.Response, Error>) in
				KubernetesClient.updateMetrics(startTime: startTime, request: request, result: result)
			}
			.flatMap { response in
				self.handleResourceOrStatus(response, eventLoop: eventLoop)
			}
	}

	func handle<T: Decodable>(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<T> {
		handleResourceOrStatus(response, eventLoop: eventLoop).flatMap { (result: ResourceOrStatus<T>) -> EventLoopFuture<T> in
			guard case let ResourceOrStatus.resource(resource) = result else {
				return eventLoop.makeFailedFuture(SwiftkubeClientError.decodingError("Expected resource type in response but got meta.v1.Status instead"))
			}

			return eventLoop.makeSucceededFuture(resource)
		}
	}

	func handleText(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<String> {
		handleResourceOrStatusText(response, eventLoop: eventLoop).flatMap { (result: ResourceOrStatus<String>) -> EventLoopFuture<String> in
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
		jsonDecoder.userInfo[CodingUserInfoKey.apiVersion] = gvr.apiVersion
		jsonDecoder.userInfo[CodingUserInfoKey.resources] = gvr.resource

		// TODO: Improve this
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

	func handleResourceOrStatusText(_ response: HTTPClient.Response, eventLoop: EventLoop) -> EventLoopFuture<ResourceOrStatus<String>> {
		guard let byteBuffer = response.body else {
			return httpClient.eventLoopGroup.next().makeFailedFuture(SwiftkubeClientError.emptyResponse)
		}

		let data = Data(buffer: byteBuffer)

		guard let logs = String(data: data, encoding: .utf8) else {
			return httpClient.eventLoopGroup.next().makeFailedFuture(SwiftkubeClientError.decodingError("Error decoding string"))
		}

		if response.status.code >= 400 {
			return eventLoop.makeFailedFuture(SwiftkubeClientError.decodingError("Error decoding string"))
		}

		return eventLoop.makeSucceededFuture(.resource(logs))
	}
}

public extension GenericKubernetesClient {

	/// Watches the API resources in the given namespace.
	///
	/// Watching resources opens a persistent connection to the API server. The connection is represented by a `SwiftkubeClientTask` instance, that acts
	/// as an active "subscription" to the events stream. The task can be cancelled any time to stop the watch.
	///
	/// ```swift
	/// let task: SwiftkubeClientTask = client.pods.watch(in: .namespace("default")) { (event, pod) in
	///    print("\(event): \(pod)")
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// The reconnect behaviour can be controlled by passing an instance of `RetryStrategy`. The default is 10 retry attempts with a fixed 5 seconds
	/// delay between each attempt. The initial delay is one second. A jitter of 0.2 seconds is applied.
	///
	/// ```swift
	/// let strategy = RetryStrategy(
	///    policy: .maxAttempts(20),
	///    backoff: .exponentialBackoff(maxDelay: 60, multiplier: 2.0),
	///    initialDelay = 5.0,
	///    jitter = 0.2
	/// )
	/// let task = client.pods.watch(in: .default, retryStrategy: strategy) { (event, pod) in print(pod) }
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - options: `ListOption` to filter/select the returned objects.
	///   - retryStrategy: A strategy to control the reconnect behaviour.
	///   - delegate: A `ResourceWatcherDelegate` instance, which is used for callbacks for new events. The client sends each
	/// event paired with the corresponding resource as a pair to the delegate's `onNext(event:)` fucntion and errors to its `onError(error:)`.
	///
	/// - Returns: A cancellable `SwiftkubeClientTask` instance, representing a streaming connetion to the API server.
	func watch<Delegate: ResourceWatcherDelegate>(
		in namespace: NamespaceSelector,
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy(),
		using delegate: Delegate
	) throws -> SwiftkubeClientTask {
		let request = try makeRequest().in(namespace).toWatch().with(options: options).build()
		let watcher = ResourceWatcher(decoder: jsonDecoder, delegate: delegate)
		let clientDelegate = ClientStreamingDelegate(watcher: watcher, logger: logger)

		let task = SwiftkubeClientTask(
			client: httpClient,
			request: request,
			streamingDelegate: clientDelegate,
			logger: logger
		)

		task.schedule(in: TimeAmount.zero)
		return task
	}

	/// Follows the logs of the specified container.
	///
	/// Following the logs of a container opens a persistent connection to the API server. The connection is represented by a `HTTPClient.Task` instance, that acts
	/// as an active "subscription" to the logs stream. The task can be cancelled any time to stop the watch.
	///
	/// ```swift
	/// let task: HTTPClient.Task<Void> = client.pods.follow(in: .namespace("default"), name: "nginx") { line in
	///    print(line)
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// The reconnect behaviour can be controlled by passing an instance of `RetryStrategy`. Per default `follow` requests are not retried.
	///
	/// ```swift
	/// let strategy = RetryStrategy(
	///    policy: .maxAttempts(20),
	///    backoff: .exponentialBackoff(maxDelay: 60, multiplier: 2.0),
	///    initialDelay = 5.0,
	///    jitter = 0.2
	/// )
	/// let task = client.pods.follow(in: .default, name: "nginx", retryStrategy: strategy) { line in print(line) }
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the Pod.
	///   - container: The name of the container.
	///   - watch: A `LogWatcherDelegate` instance, which is used as a callback for new log lines.
	///
	/// - Returns: A cancellable `SwiftkubeClientTask` instance, representing a streaming connection to the API server.
	func follow(
		in namespace: NamespaceSelector,
		name: String,
		container: String?,
		retryStrategy: RetryStrategy = RetryStrategy.never,
		delegate: LogWatcherDelegate
	) throws -> SwiftkubeClientTask {
		let request = try makeRequest().in(namespace).toFollow(pod: name, container: container).build()
		let watcher = LogWatcher(delegate: delegate)
		let clientDelegate = ClientStreamingDelegate(watcher: watcher, logger: logger)

		let task = SwiftkubeClientTask(
			client: httpClient,
			request: request,
			streamingDelegate: clientDelegate,
			logger: logger
		)

		task.schedule(in: TimeAmount.zero)
		return task
	}
}
