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

// MARK: - NamespacedGenericKubernetesClient

/// A generic Kubernetes client for namespace-scoped API resource objects.
public actor NamespacedGenericKubernetesClient<Resource: KubernetesAPIResource & NamespacedResource> {

	internal let client: GenericKubernetesClient<Resource>
	internal let config: KubernetesClientConfig

	internal init(client: GenericKubernetesClient<Resource>, config: KubernetesClientConfig) {
		self.client = client
		self.config = config
	}
}

// MARK: - ReadableResource

/// API functions for ``ReadableResources``.
public extension NamespacedGenericKubernetesClient where Resource: ReadableResource {

	/// Loads an API resource by name in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the API resource to load.
	///   - options: ``ReadOptions`` to apply to this request.
	///
	/// - Returns: The API resource specified by the given name in the given namespace.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func get(in namespace: NamespaceSelector? = nil, name: String, options: [ReadOption]? = nil) async throws -> Resource {
		try await client.get(in: namespace ?? .namespace(config.namespace), name: name, options: options)
	}

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
	/// let task = try await self.pods.watch(in: .default)
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
		in namespace: NamespaceSelector? = nil,
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy()
	) async throws -> SwiftkubeClientTask<WatchEvent<Resource>> {
		try await client.watch(
			in: namespace ?? .namespace(config.namespace),
			options: options,
			retryStrategy: retryStrategy
		)
	}
}

// MARK: - ListableResource

/// API functions for `ListableResource`.
public extension NamespacedGenericKubernetesClient where Resource: ListableResource {

	/// Lists API resources in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - options: ``ListOptions`` instance to control the behaviour of the `List` operation.
	///
	/// - Returns: A ``KubernetesAPIResourceList`` of resources.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func list(in namespace: NamespaceSelector? = nil, options: [ListOption]? = nil) async throws -> Resource.List {
		try await client.list(in: namespace ?? .namespace(config.namespace), options: options)
	}
}

// MARK: - CreatableResource

/// API functions for `CreatableResource`.
public extension NamespacedGenericKubernetesClient where Resource: CreatableResource {

	/// Creates an API resource in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - resource: A ``KubernetesAPIResource`` instance to create.
	///
	/// - Returns: The created ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func create(inNamespace namespace: NamespaceSelector? = nil, _ resource: Resource) async throws -> Resource {
		try await client.create(in: namespace ?? .namespace(config.namespace), resource)
	}

	/// Creates an API resource in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - block: A closure block, which creates a ``KubernetesAPIResource`` instance to send to the server.
	///
	/// - Returns: The created ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func create(inNamespace namespace: NamespaceSelector? = nil, _ block: () -> Resource) async throws -> Resource {
		try await client.create(in: namespace ?? .namespace(config.namespace), block())
	}
}

// MARK: - ReplaceableResource

/// API functions for `ReplaceableResource`.
public extension NamespacedGenericKubernetesClient where Resource: ReplaceableResource {

	/// Replaces, i.e. updates, an API resource with the given instance in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - resource: A ``KubernetesAPIResource`` instance to update.
	///
	/// - Returns: The created ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func update(inNamespace namespace: NamespaceSelector? = nil, _ resource: Resource) async throws -> Resource {
		try await client.update(in: namespace ?? .namespace(config.namespace), resource)
	}
}

// MARK: - DeletableResource

/// API functions for `DeletableResource`.
public extension NamespacedGenericKubernetesClient where Resource: DeletableResource {

	/// Deletes an API resource by its name in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource object to delete.
	///   - options: ``DeleteOptions`` to apply to this request.
	///
	/// - Returns: The created ``KubernetesAPIResource`
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func delete(inNamespace namespace: NamespaceSelector? = nil, name: String, options: meta.v1.DeleteOptions? = nil) async throws {
		try await client.delete(in: namespace ?? .namespace(config.namespace), name: name, options: options)
	}
}

// MARK: - CollectionDeletableResource

/// API functions for `CollectionDeletableResource`.
public extension NamespacedGenericKubernetesClient where Resource: CollectionDeletableResource {

	/// Deletes all API resources in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameter namespace: The namespace for this API request.
	///
	/// - Returns: A ``ResourceOrStatus`` instance.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func deleteAll(inNamespace namespace: NamespaceSelector? = nil) async throws {
		try await client.deleteAll(in: namespace ?? .namespace(config.namespace))
	}
}

// MARK: - StatusHavingResource

/// API functions for `StatusHavingResource`.
public extension NamespacedGenericKubernetesClient where Resource: StatusHavingResource {

	/// Reads a resource's status in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to load.
	///
	/// - Returns: The ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func getStatus(in namespace: NamespaceSelector? = nil, name: String) async throws -> Resource {
		try await client.getStatus(in: namespace ?? .namespace(config.namespace), name: name)
	}

	/// Replaces the resource's status in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to update.
	///   - resource: A ``KubernetesAPIResource`` instance to update.
	///
	/// - Returns: The updated ``KubernetesAPIResource``.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func updateStatus(in namespace: NamespaceSelector? = nil, name: String, _ resource: Resource) async throws -> Resource {
		try await client.updateStatus(in: namespace ?? .namespace(config.namespace), name: name, resource)
	}
}

// MARK: - ScalableResource

/// API functions for `ScalableResource`.
public extension NamespacedGenericKubernetesClient where Resource: ScalableResource {

	/// Reads a resource's scale in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to load.
	///
	/// - Returns: The ``autoscaling.v1.Scale`` for the desired resource.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func getScale(in namespace: NamespaceSelector? = nil, name: String) async throws -> autoscaling.v1.Scale {
		try await client.getScale(in: namespace ?? .namespace(config.namespace), name: name)
	}

	/// Replaces the resource's scale in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the resource to update.
	///   - scale: An instance of ``autoscaling.v1.Scale`` to replace.
	///
	/// - Returns: The updated ``autoscaling.v1.Scale`` for the desired resource.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func updateScale(in namespace: NamespaceSelector? = nil, name: String, scale: autoscaling.v1.Scale) async throws -> autoscaling.v1.Scale {
		try await client.updateScale(in: namespace ?? .namespace(config.namespace), name: name, scale: scale)
	}
}
