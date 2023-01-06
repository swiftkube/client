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

// MARK: - ClusterScopedGenericKubernetesClient

/// A generic Kubernetes client class for cluster-scoped API resource objects.
public class ClusterScopedGenericKubernetesClient<Resource: KubernetesAPIResource & ClusterScopedResource>: GenericKubernetesClient<Resource> {
}

// MARK: - ReadableResource

/// API functions for `ReadableResources`.
public extension ClusterScopedGenericKubernetesClient where Resource: ReadableResource {

	/// Loads an API resource by name.
	///
	/// - Parameters:
	///     - name: The name of the API resource to load.
	///     - options: A list of `ReadOptions` to apply to this request.
	///
	/// - Returns: The API resource specified by the given name.
	func get(name: String, options: [ReadOption]? = nil) async throws -> Resource {
		try await super.get(in: .allNamespaces, name: name, options: options)
	}

	/// Watches cluster-scoped resources.
	///
	/// Watching resources opens a persistent connection to the API server. The connection is represented by a `HTTPClient.Task` instance, that acts
	/// as an active "subscription" to the events stream. The task can be cancelled any time to stop the watch.
	///
	/// ```swift
	/// let task: HTTPClient.Task<Void> = client.namespaces.watch() { (event, namespace) in
	///    print("\(event): \(namespace)")
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// - Parameters:
	///     - options: A list of `ReadOptions` to apply to this request.
	///     - retryStrategy: A strategy to control the reconnect behaviour.
	///     - eventHandler: A `ResourceWatchCallback.EventHandler` instance, which is used as a callback for new events.
	///      The clients sends each event paired with the corresponding resource as a pair to the `eventHandler`.
	///
	/// - Returns: A cancellable `HTTPClient.Task` instance, representing a streaming connection to the API server.
	func watch(
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy(),
		eventHandler: @escaping ResourceWatcherCallback<Resource>.EventHandler
	) throws -> SwiftkubeClientTask {
		let delegate = ResourceWatcherCallback<Resource>(onError: nil, onEvent: eventHandler)
		return try watch(options: options, retryStrategy: retryStrategy, delegate: delegate)
	}

	/// Watches cluster-scoped resources.
	///
	/// Watching resources opens a persistent connection to the API server. The connection is represented by a `HTTPClient.Task` instance, that acts
	/// as an active "subscription" to the events stream. The task can be cancelled any time to stop the watch.
	///
	/// ```swift
	/// let task: HTTPClient.Task<Void> = client.namespaces.watch() { (event, namespace) in
	///    print("\(event): \(namespace)")
	///	}
	///
	///	task.cancel()
	/// ```
	///  The reconnect behaviour can be controlled by passing an instance of `RetryStrategy`. The default is 10 retry attempts with a fixed 5 seconds
	///  delay between each attempt. The initial delay is one second. A jitter of 0.2 seconds is applied.
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
	///     - options: A list of `ReadOptions` to apply to this request.
	///     - retryStrategy: A strategy to control the reconnect behaviour.
	///     - delegate: An ResourceWatcherDelegate instance, which is used as a callback for new events.
	///          The clients sends each event paired with the corresponding resource as a pair to the `eventHandler`.
	///          Errors are sent to the `errorHandler`.
	///
	/// - Returns: A cancellable `HTTPClient.Task` instance, representing a streaming connection to the API server.
	func watch<Delegate: ResourceWatcherDelegate>(
		options: [ListOption]? = nil,
		retryStrategy: RetryStrategy = RetryStrategy(),
		delegate: Delegate
	) throws -> SwiftkubeClientTask where Delegate.Resource == Resource {
		try super.watch(in: .allNamespaces, options: options, retryStrategy: retryStrategy, using: delegate)
	}
}

// MARK: - ListableResource

/// API functions for `ListableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: ListableResource {

	/// Lists the collection of API resources.
	///
	/// - Parameter options: `ListOptions` instance to control the behaviour of the `List` operation.
	///
	/// - Returns: A `KubernetesAPIResourceList` of resources.
	func list(options: [ListOption]? = nil) async throws -> Resource.List {
		try await super.list(in: .allNamespaces, options: options)
	}
}

// MARK: - CreatableResource

/// API functions for `CreatableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: CreatableResource {

	/// Creates an API resource.
	///
	/// - Parameter resource: A `KubernetesAPIResource` instance to create.
	///
	/// - Returns: The created `KubernetesAPIResource`.
	func create(_ resource: Resource) async throws -> Resource {
		try await super.create(in: .allNamespaces, resource)
	}

	/// Creates an API resource.
	///
	/// - Parameter block: A closure block, which creates a `KubernetesAPIResource` instance to send to the server.
	///
	/// - Returns: The created `KubernetesAPIResource`.
	func create(_ block: () -> Resource) async throws -> Resource {
		try await super.create(in: .allNamespaces, block())
	}
}

// MARK: - ReplaceableResource

/// API functions for `ReplaceableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: ReplaceableResource {

	/// Replaces, i.e. updates, an API resource with the given instance.
	///
	/// - Parameter resource: A `KubernetesAPIResource` instance to update.
	///
	/// - Returns: The updated `KubernetesAPIResource`.
	func update(_ resource: Resource) async throws -> Resource {
		try await super.update(in: .allNamespaces, resource)
	}
}

// MARK: - DeletableResource

/// API functions for `DeletableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: DeletableResource {

	/// Deletes an API resource by its name.
	///
	/// - Parameters:
	///   - name: The name of the resource.
	///   - options: An instance of `meta.v1.DeleteOptions` to control the behaviour of the `Delete` operation.
	///
	/// - Returns: A `ResourceOrStatus` instance.
	func delete(name: String, options: meta.v1.DeleteOptions? = nil) async throws {
		try await super.delete(in: .allNamespaces, name: name, options: options)
	}
}

// MARK: - CollectionDeletableResource

/// API functions for `CollectionDeletableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: CollectionDeletableResource {

	/// Deletes all API resources in the target collection.
	///
	/// - Returns: A `ResourceOrStatus` instance.
	func deleteAll() async throws {
		try await super.deleteAll(in: .allNamespaces)
	}
}

// MARK: - StatusHavingResource

/// API functions for `StatusHavingResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: StatusHavingResource {

	/// Loads an API resource's status by name.
	///
	/// - Parameters:
	///   - name: The name of the API resource to load.
	///
	/// - Returns: The API resource specified by the given name.
	func getStatus(name: String) async throws -> Resource {
		try await super.getStatus(in: .allNamespaces, name: name)
	}

	/// Replaces, i.e. updates, an API resource's status .
	///
	/// - Parameters:
	///   - name: The name of the resoruce to update.
	///   - resource: A `KubernetesAPIResource` instance to update.
	///
	/// - Returns: The updated `KubernetesAPIResource`.
	func updateStatus(name: String, _ resource: Resource) async throws -> Resource {
		try await super.updateStatus(in: .allNamespaces, name: name, resource)
	}
}

// MARK: - ScalableResource

/// API functions for `ScalableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: ScalableResource {

	/// Loads an API resource's scale by name.
	///
	/// - Parameters:
	///   - name: The name of the API resource to load.
	///
	/// - Returns: The `autoscaling.v1.Scale` of the resource specified by the given name.
	func getScale(name: String) async throws -> autoscaling.v1.Scale {
		try await super.getScale(in: .allNamespaces, name: name)
	}

	/// Replaces, i.e. updates, an API resource's scale.
	///
	/// - Parameters:
	///   - name: The name of the resource to update.
	///   - scale: An instance of a `autoscaling.v1.Scale` object to apply to the resource.
	///   - resource: A `autoscaling.v1.Scale` instance to update.
	///
	/// - Returns: The updated `autoscaling.v1.Scale`.
	func updateScale(name: String, scale: autoscaling.v1.Scale) async throws -> autoscaling.v1.Scale {
		try await super.updateScale(in: .allNamespaces, name: name, scale: scale)
	}
}
