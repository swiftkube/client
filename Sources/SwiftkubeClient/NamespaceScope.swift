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

public protocol NamespaceScopedResourceHandler: BaseHandler {

	func list(in namespace: NamespaceSelector?, selector: ListSelector?) -> EventLoopFuture<ResourceList>

	func get(in namespace: NamespaceSelector?, name: String) -> EventLoopFuture<Resource>

	func create(inNamespace namespace: String?, _ resource: Resource) -> EventLoopFuture<Resource>

	func create(inNamespace namespace: String?, _ block: () -> Resource) -> EventLoopFuture<Resource>

	func update<R: ResourceWithMetadata>(inNamespace namespace: String?, _ resource: R) -> EventLoopFuture<R> where R == Resource

	func delete(inNamespace namespace: String?, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>>
}

public extension NamespaceScopedResourceHandler {

	func list(in namespace: NamespaceSelector? = nil, selector: ListSelector? = nil) -> EventLoopFuture<ResourceList> {
		return _list(in: namespace ?? .namespace(self.config.namespace) , selector: selector)
	}

	func get(in namespace: NamespaceSelector? = nil, name: String) -> EventLoopFuture<Resource> {
		return _get(in: namespace ?? .namespace(self.config.namespace), name: name)
	}

	func create(inNamespace namespace: String? = nil, _ resource: Resource) -> EventLoopFuture<Resource> {
		return _create(in: .namespace(namespace ?? self.config.namespace), resource)
	}

	func create(inNamespace namespace: String? = nil, _ block: () -> Resource) -> EventLoopFuture<Resource> {
		return _create(in: .namespace(namespace ?? self.config.namespace), block())
	}

	func delete(inNamespace namespace: String? = nil, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return _delete(in: .namespace(namespace ?? self.config.namespace), name: name)
	}
}

public extension NamespaceScopedResourceHandler where Resource: ResourceWithMetadata {

	func update(inNamespace namespace: String?, _ resource: Resource) -> EventLoopFuture<Resource> {
		return _update(in: .namespace(namespace ?? self.config.namespace), resource)
	}
}
