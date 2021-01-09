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
	/// - Parameter name: The name of the API resource to load.
	///
	/// - Returns: An `EventLoopFuture` holding the API resource specified by the given name.
	func get(name: String, options: [ReadOption]? = nil) -> EventLoopFuture<Resource> {
		super.get(in: .allNamespaces, name: name, options: options)
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
	/// - Parameter eventHandler: A `ResourceWatch.EventHandler` instance, which is used as a callback for new events. The clients sends each
	/// event paired with the corresponding resource as a pair to the `eventHandler`.
	///
	/// - Returns: A cancellable `HTTPClient.Task` instance, representing a streaming connetion to the API server.
	func watch(eventHandler: @escaping ResourceWatch<Resource>.EventHandler) throws -> HTTPClient.Task<Void> {
		try super.watch(in: .allNamespaces, using: ResourceWatch<Resource>(eventHandler))
	}
}

// MARK: - ListableResource

/// API functions for `ListableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: ListableResource {

	/// Lists the collection of API resources.
	///
	/// - Parameter options: `ListOptions` instance to control the behaviour of the `List` operation.
	///
	/// - Returns: An `EventLoopFuture` holding a `KubernetesAPIResourceList` of resources.
	func list(options: [ListOption]? = nil) -> EventLoopFuture<Resource.List> {
		super.list(in: .allNamespaces, options: options)
	}
}

// MARK: - CreatableResource

/// API functions for `CreatableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: CreatableResource {

	/// Creates an API resource.
	///
	/// - Parameter resource: A `KubernetesAPIResource` instance to create.
	///
	/// - Returns: An `EventLoopFuture` holding the created `KubernetesAPIResource`.
	func create(_ resource: Resource) -> EventLoopFuture<Resource> {
		super.create(in: .allNamespaces, resource)
	}

	/// Creates an API resource.
	///
	/// - Parameter block: A closure block, which creates a `KubernetesAPIResource` instance to send to the server.
	///
	/// - Returns: An `EventLoopFuture` holding the created `KubernetesAPIResource`.
	func create(_ block: () -> Resource) -> EventLoopFuture<Resource> {
		super.create(in: .allNamespaces, block())
	}
}

// MARK: - ReplaceableResource

/// API functions for `ReplaceableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: ReplaceableResource {

	/// Replaces, i.e. updates, an API resource with the given instance.
	///
	/// - Parameter resource: A `KubernetesAPIResource` instance to update.
	///
	/// - Returns: An `EventLoopFuture` holding the updated `KubernetesAPIResource`.
	func update(_ resource: Resource) -> EventLoopFuture<Resource> {
		super.update(in: .allNamespaces, resource)
	}
}

// MARK: - DeletableResource

/// API functions for `DeletableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: DeletableResource {

	/// Deletes an API resource by its name.
	///
	/// - Parameters:
	///   - name: The name of the resource.
	///   - options: An instnace of `meta.v1.DeleteOptions` to control the behaviour of the `Delete` operation.
	///
	/// - Returns: An `EventLoopFuture` holding a `ResourceOrStatus` instance.
	func delete(name: String, options: meta.v1.DeleteOptions? = nil) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		super.delete(in: .allNamespaces, name: name, options: options)
	}
}

// MARK: - CollectionDeletableResource

/// API functions for `CollectionDeletableResource`.
public extension ClusterScopedGenericKubernetesClient where Resource: CollectionDeletableResource {

	/// Deletes all API resources in the target collection.
	///
	/// - Returns: An `EventLoopFuture` holding a `ResourceOrStatus` instance.
	func deleteAll() -> EventLoopFuture<ResourceOrStatus<Resource>> {
		super.deleteAll(in: .allNamespaces)
	}
}
