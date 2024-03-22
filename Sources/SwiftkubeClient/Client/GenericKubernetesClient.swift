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

// MARK: - GenericKubernetesClient

/// A generic client implementation following the Kubernetes API style.
public actor GenericKubernetesClient<Resource: KubernetesAPIResource> {

	public let gvr: GroupVersionResource

	internal let httpClient: HTTPClient
	internal let config: KubernetesClientConfig
	internal let logger: Logger
	internal let jsonDecoder: JSONDecoder

	/// Create a new instance of the generic client.
	///
	/// The  ``GroupVersionKind`` of this client instance will be inferred by the generic constraint.
	///
	/// ```swift
	/// let client = GenericKubernetesClient<core.v1.Deployment>(httpClient: client, config: config)
	/// ```
	///
	/// - Parameters:
	///   - httpClient: An instance of Async ``HTTPClient``.
	///   - config: The configuration for this client instance.
	///   - jsonDecoder: An instance of ``JSONDecoder`` to use by this client.
	///   - logger: The logger to use for this client.
	internal init(httpClient: HTTPClient, config: KubernetesClientConfig, jsonDecoder: JSONDecoder, logger: Logger? = nil) {
		self.init(httpClient: httpClient, config: config, gvr: GroupVersionResource(of: Resource.self)!, jsonDecoder: jsonDecoder, logger: logger)
	}

	/// Create a new instance of the generic client for the given ``GroupVersionKind``.
	///
	/// - Parameters:
	///   - httpClient: An instance of Async ``HTTPClient``.
	///   - config: The configuration for this client.
	///   - gvr: The ``GroupVersionResource`` of the target resource.
	///   - jsonDecoder: An instance of ``JSONDecoder`` to use by this client.
	///   - logger: The logger to use for this client.
	internal init(httpClient: HTTPClient, config: KubernetesClientConfig, gvr: GroupVersionResource, jsonDecoder: JSONDecoder, logger: Logger? = nil) {
		self.httpClient = httpClient
		self.config = config
		self.gvr = gvr
		self.jsonDecoder = jsonDecoder
		self.logger = logger ?? SwiftkubeClient.loggingDisabled
	}
}

// MARK: RequestHandlerType

extension GenericKubernetesClient: RequestHandlerType {}

// MARK: - GenericKubernetesClient + MakeRequest

internal extension GenericKubernetesClient {
	func makeRequest() -> NamespaceStep {
		RequestBuilder(config: config, gvr: gvr)
	}
}

// MARK: - GenericKubernetesClient

public extension GenericKubernetesClient {

	/// Loads an API resource by name in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the API resource to load.
	///   - options: ``ReadOptions`` to apply to this request.
	///
	/// - Returns: The API resource specified by the given name in the given namespace.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func get(in namespace: NamespaceSelector, name: String, options: [ReadOption]? = nil) async throws -> Resource {
		let request = try makeRequest()
			.in(namespace)
			.toGet()
			.resource(withName: name)
			.with(options: options)
			.build()

		return try await dispatch(request: request, expect: Resource.self)
	}

	/// Creates an API resource in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - resource: A ``KubernetesAPIResource`` instance to create.
	///
	/// - Returns: The created ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func create(in namespace: NamespaceSelector, _ resource: Resource) async throws -> Resource {
		let request = try makeRequest()
			.in(namespace)
			.toPost()
			.body(resource)
			.build()

		return try await dispatch(request: request, expect: Resource.self)
	}

	/// Replaces, i.e. updates, an API resource with the given instance in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - resource: A ``KubernetesAPIResource`` instance to update.
	///
	/// - Returns: The created ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func update(in namespace: NamespaceSelector, _ resource: Resource) async throws -> Resource {
		let request = try makeRequest()
			.in(namespace)
			.toPut()
			.resource(withName: resource.name)
			.body(.resource(payload: resource))
			.build()

		return try await dispatch(request: request, expect: Resource.self)
	}

	/// Deletes an API resource by its name in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource object to delete.
	///   - options: ``DeleteOptions`` to apply to this request.
	///
	/// - Returns: The created ``KubernetesAPIResource`
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func delete(in namespace: NamespaceSelector, name: String, options: meta.v1.DeleteOptions?) async throws {
		let request = try makeRequest()
			.in(namespace)
			.toDelete()
			.resource(withName: name)
			.with(options: options)
			.build()

		_ = try await dispatch(request: request, expect: meta.v1.Status.self)
	}

	/// Deletes all API resources in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameter namespace: The namespace for this API request.
	///
	/// - Returns: A ``ResourceOrStatus`` instance.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func deleteAll(in namespace: NamespaceSelector) async throws {
		let request = try makeRequest()
			.in(namespace)
			.toDelete()
			.build()

		_ = try await dispatch(request: request, expect: meta.v1.Status.self)
	}
}

// MARK: - GenericKubernetesClient + ListableResource

public extension GenericKubernetesClient where Resource: ListableResource {

	/// Lists API resources in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - options: ``ListOptions`` instance to control the behaviour of the `List` operation.
	///
	/// - Returns: A ``KubernetesAPIResourceList`` of resources.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func list(in namespace: NamespaceSelector, options: [ListOption]? = nil) async throws -> Resource.List {
		let request = try makeRequest()
			.in(namespace)
			.toGet()
			.with(options: options)
			.build()

		return try await dispatch(request: request, expect: Resource.List.self)
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
	/// - Returns: The ``autoscaling.v1.Scale`` for the desired resource.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func getScale(in namespace: NamespaceSelector, name: String) async throws -> autoscaling.v1.Scale {
		let request = try makeRequest()
			.in(namespace)
			.toGet()
			.resource(withName: name)
			.subResource(.scale)
			.build()

		return try await dispatch(request: request, expect: autoscaling.v1.Scale.self)
	}

	/// Replaces the resource's scale in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to update.
	///   - scale: An instance of ``autoscaling.v1.Scale`` to replace.
	///
	/// - Returns: The updated ``autoscaling.v1.Scale`` for the desired resource.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func updateScale(in namespace: NamespaceSelector, name: String, scale: autoscaling.v1.Scale) async throws -> autoscaling.v1.Scale {
		let request = try makeRequest()
			.in(namespace)
			.toPut()
			.resource(withName: name)
			.body(.subResource(type: .scale, payload: scale))
			.build()

		return try await dispatch(request: request, expect: autoscaling.v1.Scale.self)
	}
}

// MARK: - GenericKubernetesClient + Logs

internal extension GenericKubernetesClient {

	/// Loads a container's logs once without streaming.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the pod.
	///   - container: The name of the container.
	///   - previous: Whether to request the logs of the previous instance of the container.
	///   - timestamps: Whether to include timestamps on the log lines.
	///   - tailLines: The number of log lines to load.
	///
	/// - Returns: The container logs as a single String.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func logs(in namespace: NamespaceSelector, name: String, container: String?, previous: Bool = false, timestamps: Bool = false, tailLines: Int? = nil) async throws -> String {
		let request = try makeRequest()
			.in(namespace)
			.toLogs(pod: name, container: container, previous: previous, timestamps: timestamps, tailLines: tailLines)
			.subResource(.log)
			.build()

		return try await dispatch(request: request)
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
	/// - Returns: The ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func getStatus(in namespace: NamespaceSelector, name: String) async throws -> Resource {
		let request = try makeRequest()
			.in(namespace)
			.toGet()
			.resource(withName: name)
			.subResource(.status)
			.build()

		return try await dispatch(request: request, expect: Resource.self)
	}

	/// Replaces the resource's status in the given namespace.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to update.
	///   - resource: A ``KubernetesAPIResource`` instance to update.
	///
	/// - Returns: The updated ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func updateStatus(in namespace: NamespaceSelector, name: String, _ resource: Resource) async throws -> Resource {
		let request = try makeRequest()
			.in(namespace)
			.toPut()
			.resource(withName: name)
			.body(.subResource(type: .status, payload: resource))
			.build()

		return try await dispatch(request: request, expect: Resource.self)
	}
}

// MARK: - GenericKubernetesClient + Watch & Follow

public extension GenericKubernetesClient {

	/// Watches the API resources in the given namespace.
	///
	/// Watching resources opens a persistent connection to the API server. The connection is represented by a
	/// ``SwiftkubeClientTask`` instance, that acts as an active "subscription" to the events stream.
	///
	/// The task instance must be started explicitly via ``SwiftkubeClientTask/start()``, which returns an
	/// ``AsyncThrowingStream``, that begins yielding events immediately as they are received from the Kubernetes API server.
	///
	/// The async stream buffers its results if there are no active consumers. The ``AsyncThrowingStream.BufferingPolicy.unbounded``
	/// buffering policy is used, which should be taken into consideration.
	///
	/// The task can be cancelled by calling its ``SwiftkubeClientTask/cancel()`` function.
	///
	/// Example:
	///
	/// ```swift
	/// let task = try await client.configMaps.watch(in: .default)
	/// let stream = await task.start()
	/// for try await item in stream {
	///   print(item)
	/// }
	/// ```
	///
	/// The task is executed indefinitely. Upon encountering non-transient errors this tasks reconnects to the
	/// Kubernetes API server, basically restarting the previous ``GenericKubernetesClient/watch(in:options:retryStrategy:)``
	/// or ``GenericKubernetesClient/follow(in:name:container:retryStrategy:)`` call.
	///
	/// The reconnect behaviour can be controlled by passing an instance of ``RetryStrategy``. The default is 10 retry
	/// attempts with a fixed 5 seconds delay between each attempt. The initial delay is one second. A jitter of 0.2 seconds is applied.
	///
	/// ```swift
	/// let strategy = RetryStrategy(
	///    policy: .maxAttempts(20),
	///    backoff: .exponentialBackoff(maxDelay: 60, multiplier: 2.0),
	///    initialDelay = 5.0,
	///    jitter = 0.2
	/// )
	/// let task = try await client.pods.watch(in: .default, retryStrategy: strategy)
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - options: ``ListOption`` to filter/select the returned objects.
	///   - retryStrategy: A strategy to control the reconnect behaviour.
	///
	/// - Returns: A ``SwiftkubeClientTask`` instance, representing a streaming connection to the API server.
	func watch(
		in namespace: NamespaceSelector,
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy()
	) async throws -> SwiftkubeClientTask<WatchEvent<Resource>> {
		let request = try makeRequest().in(namespace).toWatch().with(options: options).build()

		return SwiftkubeClientTask(
			client: httpClient,
			request: request,
			transformer: ResourceEventTransformer(decoder: jsonDecoder),
			retryStrategy: retryStrategy,
			logger: logger
		)
	}

	/// Follows the logs of the specified container.
	///
	/// Following the logs of a container opens a persistent connection to the API server. The connection is represented
	/// by a ``SwiftkubeClientTask`` instance, that acts as an active "subscription" to the logs stream.
	///
	/// The task instance must be started explicitly via ``SwiftkubeClientTask/start()``, which returns an
	/// ``AsyncThrowingStream``, that begins yielding log lines immediately as they are received from the Kubernetes API server.
	///
	/// The async stream buffers its results if there are no active consumers. The ``AsyncThrowingStream.BufferingPolicy.unbounded``
	/// buffering policy is used, which should be taken into consideration.
	///
	/// The task can be cancelled by calling its ``SwiftkubeClientTask/cancel()`` function.
	///
	/// Example:
	///
	/// ```swift
	/// let task = try await client.pods.follow(in: .namespace("default"), name: "nginx")
	/// let stream = await task.start()
	/// for try await line in stream {
	///   print(line)
	///	}
	/// ```
	///
	/// Per default `follow` requests are not retried. To enable and control reconnect behaviour pass an instance
	/// of ``RetryStrategy``.
	///
	/// ```swift
	/// let strategy = RetryStrategy(
	///    policy: .maxAttempts(20),
	///    backoff: .exponentialBackoff(maxDelay: 60, multiplier: 2.0),
	///    initialDelay = 5.0,
	///    jitter = 0.2
	/// )
	/// let task = await client.pods.follow(in: .default, name: "nginx", retryStrategy: strategy)
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the Pod.
	///   - container: The name of the container.
	///   - timestamps: Whether to include timestamps on the log lines.
	///   - tailLines: The number of log lines to load.
	///   - retryStrategy: An instance of a ``RetryStrategy`` configuration to use.
	///
	/// - Returns: A ``SwiftkubeClientTask`` instance, representing a streaming connection to the API server.
	func follow(
		in namespace: NamespaceSelector,
		name: String,
		container: String?,
		timestamps: Bool = false,
		tailLines: Int? = nil,
		retryStrategy: RetryStrategy = RetryStrategy.never
	) async throws -> SwiftkubeClientTask<String> {
		let request = try makeRequest().in(namespace).toFollow(pod: name, container: container, timestamps: timestamps, tailLines: tailLines).build()

		return SwiftkubeClientTask(
			client: httpClient,
			request: request,
			transformer: IdentityTransfomer(),
			retryStrategy: retryStrategy,
			logger: logger
		)
	}
}
