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
import NIO
import SwiftkubeModel

public class ClusterScopedGenericKubernetesClient<Resource: KubernetesAPIResource & ClusterScopedResource>: GenericKubernetesClient<Resource> {

	public func get(name: String) -> EventLoopFuture<Resource> {
		return super.get(in: .allNamespaces, name: name)
	}

	public func create(_ resource: Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .allNamespaces, resource)
	}

	public func create(_ block: () -> Resource) -> EventLoopFuture<Resource> {
		return super.create(in: .allNamespaces, block())
	}

	public func delete(name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return super.delete(in: .allNamespaces, name: name)
	}

	public func watch(eventHandler: @escaping ResourceWatch<Resource>.EventHandler) throws -> HTTPClient.Task<Void> {
		return try super.watch(in: .allNamespaces, using: ResourceWatch<Resource>(eventHandler))
	}
}

public extension ClusterScopedGenericKubernetesClient where Resource: ListableResource {

	func list(options: [ListOption]? = nil) -> EventLoopFuture<Resource.List> {
		return super.list(in: .allNamespaces, options: options)
	}
}
