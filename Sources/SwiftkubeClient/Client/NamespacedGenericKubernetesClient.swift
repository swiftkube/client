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
import NIO
import SwiftkubeModel

// MARK: - NamespacedGenericKubernetesClient

/// A generic Kubernetes client class for namespace-scoped API resource objects.
public class NamespacedGenericKubernetesClient<Resource: KubernetesAPIResource & NamespacedResource>: GenericKubernetesClient<Resource> {
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
		try await super.get(in: namespace ?? .namespace(config.namespace), name: name, options: options)
	}

	/// Watches the API resources in the given namespace.
	///
	/// Watching resources opens a persistent connection to the API server. The connection is represented by a ``SwiftkubeClientTask`` instance, that acts
	/// as an active "subscription" to the events stream. The task can be cancelled any time to stop the watch.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// ```swift
	/// let task: SwiftkubeClientTask = client.pods.watch(in: .namespace("default")) { (event, pod) in
	///    print("\(event): \(pod)")
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// The reconnect behaviour can be controlled by passing an instance of  ``RetryStrategy``. The default is 10 retry attempts with a fixed 5 seconds
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
	///   - options: ``ListOption`` to filter/select the returned objects.
	///   - retryStrategy: A strategy to control the reconnect.
	///   - eventHandler: 	/// Loads an API resource by name in the given namespace.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the API resource to load.
	///   - options: ReadOptions to apply to this request.
	///
	/// - Returns: The API resource specified by the given name in the given namespace.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	///
	/// - Returns: A cancellable ``SwiftkubeClientTask`` instance, representing a streaming connection to the API server.
	func watch(
		in namespace: NamespaceSelector? = nil,
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy(),
		eventHandler: @escaping ResourceWatcherCallback<Resource>.EventHandler
	) throws -> SwiftkubeClientTask {
		let delegate = ResourceWatcherCallback<Resource>(onError: nil, onEvent: eventHandler)
		return try watch(in: namespace, options: options, retryStrategy: retryStrategy, delegate: delegate)
	}

	/// Watches the API resources in the given namespace.
	///
	/// Watching resources opens a persistent connection to the API server. The connection is represented by a ``SwiftkubeClientTask`` instance, that acts
	/// as an active "subscription" to the events stream. The task can be cancelled any time to stop the watch.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// ```swift
	/// let task: SwiftkubeClientTask = client.pods.watch(in: .namespace("default")) { (event, pod) in
	///    print("\(event): \(pod)")
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// The reconnect behaviour can be controlled by passing an instance of  ``RetryStrategy``. The default is 10 retry attempts with a fixed 5 seconds
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
	///   - options: ``ListOption`` to filter/select the returned objects.
	///   - retryStrategy: A strategy to control the reconnect behaviour.
	///   - delegate: A ``ResourceWatcherDelegate`` instance, which is used for callbacks for new events. The client sends each
	/// event paired with the corresponding resource as a pair to the delegate's ``ResourceWatcherDelegate/onEvent(event:resource:)`` function
	/// and errors to its ``ResourceWatcherDelegate/onError(error:)``.
	///
	/// - Returns: A cancellable ``SwiftkubeClientTask`` instance, representing a streaming connection to the API server.
	func watch<Delegate: ResourceWatcherDelegate>(
		in namespace: NamespaceSelector? = nil,
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy(),
		delegate: Delegate
	) throws -> SwiftkubeClientTask where Delegate.Resource == Resource {
		try super.watch(
			in: namespace ?? .namespace(config.namespace),
			options: options,
			retryStrategy: retryStrategy,
			using: delegate
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
		try await super.list(in: namespace ?? .namespace(config.namespace), options: options)
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
		try await super.create(in: namespace ?? .namespace(config.namespace), resource)
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
		try await super.create(in: namespace ?? .namespace(config.namespace), block())
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
		try await super.update(in: namespace ?? .namespace(config.namespace), resource)
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
		try await super.delete(in: namespace ?? .namespace(config.namespace), name: name, options: options)
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
		try await super.deleteAll(in: namespace ?? .namespace(config.namespace))
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
		try await super.getStatus(in: namespace ?? .namespace(config.namespace), name: name)
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
		try await super.updateStatus(in: namespace ?? .namespace(config.namespace), name: name, resource)
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
		try await super.getScale(in: namespace ?? .namespace(config.namespace), name: name)
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
		try await super.updateScale(in: namespace ?? .namespace(config.namespace), name: name, scale: scale)
	}
}
