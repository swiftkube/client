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

import Foundation
import NIO
import SwiftkubeModel

public protocol ClusterScopedResourceHandler: BaseHandler {

	func list(selector: ListSelector?) -> EventLoopFuture<ResourceList>

	func get(name: String) -> EventLoopFuture<Resource>

	func create(_ resource: Resource) -> EventLoopFuture<Resource>

	func update<R: ResourceWithMetadata>(_ resource: R) -> EventLoopFuture<R> where R == Resource

	func delete(name: String) -> EventLoopFuture<ResourceOrStatus<Resource>>
}

public extension ClusterScopedResourceHandler {

	func list(selector: ListSelector? = nil) -> EventLoopFuture<ResourceList> {
		return _list(in: .allNamespaces, selector: selector)
	}

	func get(name: String) -> EventLoopFuture<Resource> {
		return _get(in: .allNamespaces, name: name)
	}

	func create(_ resource: Resource) -> EventLoopFuture<Resource> {
		return _create(in: .allNamespaces, resource)
	}

	func delete(name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return _delete(in: .allNamespaces, name: name)
	}
}

public extension ClusterScopedResourceHandler where Resource: ResourceWithMetadata {

	func update(_ resource: Resource) -> EventLoopFuture<Resource> {
		return _update(in: .allNamespaces, resource)
	}
}

public extension ClusterScopedResourceHandler {

	func watch(eventHandler: @escaping ResourceWatch<Resource>.EventHandler) -> EventLoopFuture<Void> {
		return watch(in: .allNamespaces, watch: ResourceWatch<Resource>(eventHandler))
	}
}
