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

public class NamespacedGenericKubernetesClient<Resource: KubernetesAPIResource & NamespacedResource>: GenericKubernetesClient<Resource> {

	public override func get(in namespace: NamespaceSelector? = nil, name: String) -> EventLoopFuture<Resource> {
		return super.get(in: namespace ?? .namespace(self.config.namespace), name: name)
	}

	public func create(inNamespace namespace: NamespaceSelector? = nil, _ resource: Resource) -> EventLoopFuture<Resource> {
		return super.create(in: namespace ?? .namespace(config.namespace), resource)
	}

	public func create(inNamespace namespace: NamespaceSelector? = nil, _ block: () -> Resource) -> EventLoopFuture<Resource> {
		return super.create(in: namespace ?? .namespace(config.namespace), block())
	}

	public func update(inNamespace namespace: NamespaceSelector? = nil, _ resource: Resource) -> EventLoopFuture<Resource> {
		return super.update(in: namespace ?? .namespace(config.namespace), resource)
	}

	public func delete(inNamespace namespace: NamespaceSelector? = nil, name: String) -> EventLoopFuture<ResourceOrStatus<Resource>> {
		return super.delete(in: namespace ?? .namespace(config.namespace), name: name)
	}

	public func watch(in namespace: NamespaceSelector? = nil, eventHandler: @escaping ResourceWatch<Resource>.EventHandler) throws -> HTTPClient.Task<Void> {
		return try super.watch(in: namespace ?? NamespaceSelector.allNamespaces, using: ResourceWatch<Resource>(logger: logger, eventHandler))
	}

	public func follow(in namespace: NamespaceSelector? = nil, name: String, container: String?, lineHandler: @escaping LogWatch.LineHandler) throws -> HTTPClient.Task<Void> {
		return try super.follow(in: namespace ?? NamespaceSelector.allNamespaces, name: name, container: container, using: LogWatch(logger: logger, lineHandler))
	}
}

public extension NamespacedGenericKubernetesClient where Resource: ListableResource {

	func list(in namespace: NamespaceSelector? = nil, options: [ListOption]? = nil) -> EventLoopFuture<Resource.List> {
		return super.list(in: namespace ?? .namespace(self.config.namespace) , options: options)
	}
}
