//
// Copyright 2025 Swiftkube Project
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
import NIO
import SwiftkubeModel

// MARK: - ClusterScopedGenericKubernetesClient

/// A generic Kubernetes client for cluster-scoped API resource objects.
public actor ClusterScopedGenericKubernetesClient<Resource: KubernetesAPIResource & ClusterScopedResource> {

	internal let client: GenericKubernetesClient<Resource>
	internal let config: KubernetesClientConfig

	internal init(client: GenericKubernetesClient<Resource>, config: KubernetesClientConfig) {
		self.client = client
		self.config = config
	}
}

// MARK: - ReadableResource

/// API functions for ``ReadableResource``.
public extension ClusterScopedGenericKubernetesClient where Resource: ReadableResource {

	/// Loads an API resource by name.
	///
	/// - Parameters:
	///     - name: The name of the API resource to load.
	///     - options: A list of ``ReadOptions`` to apply to this request.
	///
	/// - Returns: The API resource specified by the given name.
	func get(name: String, options: [ReadOption]? = nil) async throws -> Resource {
		try await client.get(in: .allNamespaces, name: name, options: options)
	}

	/// Watches cluster-scoped resources.
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
	/// let task = try await self.nodes.watch(in: .default)
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
	/// let task = try await self.pods.watch(in: .default, retryStrategy: strategy)
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - options: ``ListOption`` to filter/select the returned objects.
	///   - retryStrategy: A strategy to control the reconnect behaviour.
	///
	/// - Returns: A ``SwiftkubeClientTask`` instance, representing a streaming connection to the API server.
	func watch(
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy()
	) async throws -> SwiftkubeClientTask<WatchEvent<Resource>> {
		try await client.watch(in: .allNamespaces, options: options, retryStrategy: retryStrategy)
	}
}

// MARK: - ListableResource

/// API functions for ``ListableResource``.
public extension ClusterScopedGenericKubernetesClient where Resource: ListableResource {

	/// Lists the collection of API resources.
	///
	/// - Parameter options: ``ListOptions`` instance to control the behaviour of the `List` operation.
	///
	/// - Returns: A ``KubernetesAPIResourceList`` of resources.
	func list(options: [ListOption]? = nil) async throws -> Resource.List {
		try await client.list(in: .allNamespaces, options: options)
	}
}

// MARK: - CreatableResource

/// API functions for `CreatableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: CreatableResource {

	/// Creates an API resource.
	///
	/// - Parameter resource: A ``KubernetesAPIResource`` instance to create.
	///
	/// - Returns: The created ``KubernetesAPIResource``.
	func create(_ resource: Resource) async throws -> Resource {
		try await client.create(in: .allNamespaces, resource)
	}

	/// Creates an API resource.
	///
	/// - Parameter block: A closure block, which creates a ``KubernetesAPIResource`` instance to send to the server.
	///
	/// - Returns: The created ``KubernetesAPIResource``.
	func create(_ block: () -> Resource) async throws -> Resource {
		try await client.create(in: .allNamespaces, block())
	}
}

// MARK: - ReplaceableResource

/// API functions for `ReplaceableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: ReplaceableResource {

	/// Replaces, i.e. updates, an API resource with the given instance.
	///
	/// - Parameter resource: A ``KubernetesAPIResource`` instance to update.
	///
	/// - Returns: The updated ``KubernetesAPIResource``.
	func update(_ resource: Resource) async throws -> Resource {
		try await client.update(in: .allNamespaces, resource)
	}
}

// MARK: - DeletableResource

/// API functions for ``DeletableResource``.
public extension ClusterScopedGenericKubernetesClient where Resource: DeletableResource {

	/// Deletes an API resource by its name.
	///
	/// - Parameters:
	///   - name: The name of the resource.
	///   - options: An instance of ``meta.v1.DeleteOptions`` to control the behaviour of the `Delete` operation.
	///
	func delete(name: String, options: meta.v1.DeleteOptions? = nil) async throws {
		try await client.delete(in: .allNamespaces, name: name, options: options)
	}
}

// MARK: - CollectionDeletableResource

/// API functions for ``CollectionDeletableResource``.
public extension ClusterScopedGenericKubernetesClient where Resource: CollectionDeletableResource {

	/// Deletes all API resources in the target collection.
	///
	func deleteAll() async throws {
		try await client.deleteAll(in: .allNamespaces)
	}
}

// MARK: - StatusHavingResource

/// API functions for ``StatusHavingResource``.
public extension ClusterScopedGenericKubernetesClient where Resource: StatusHavingResource {

	/// Loads an API resource's status by name.
	///
	/// - Parameters:
	///   - name: The name of the API resource to load.
	///
	/// - Returns: The API resource specified by the given name.
	func getStatus(name: String) async throws -> Resource {
		try await client.getStatus(in: .allNamespaces, name: name)
	}

	/// Replaces, i.e. updates, an API resource's status .
	///
	/// - Parameters:
	///   - name: The name of the resoruce to update.
	///   - resource: A `KubernetesAPIResource` instance to update.
	///
	/// - Returns: The updated ``KubernetesAPIResource``.
	func updateStatus(name: String, _ resource: Resource) async throws -> Resource {
		try await client.updateStatus(in: .allNamespaces, name: name, resource)
	}
}

// MARK: - ScalableResource

/// API functions for ``ScalableResource``.
public extension ClusterScopedGenericKubernetesClient where Resource: ScalableResource {

	/// Loads an API resource's scale by name.
	///
	/// - Parameters:
	///   - name: The name of the API resource to load.
	///
	/// - Returns: The ``autoscaling.v1.Scale`` of the resource specified by the given name.
	func getScale(name: String) async throws -> autoscaling.v1.Scale {
		try await client.getScale(in: .allNamespaces, name: name)
	}

	/// Replaces, i.e. updates, an API resource's scale.
	///
	/// - Parameters:
	///   - name: The name of the resource to update.
	///   - scale: An instance of a ``autoscaling.v1.Scale`` object to apply to the resource.
	///   - resource: A ``autoscaling.v1.Scale`` instance to update.
	///
	/// - Returns: The updated ``autoscaling.v1.Scale``.
	func updateScale(name: String, scale: autoscaling.v1.Scale) async throws -> autoscaling.v1.Scale {
		try await client.updateScale(in: .allNamespaces, name: name, scale: scale)
	}
}
