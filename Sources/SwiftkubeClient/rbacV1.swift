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
import AsyncHTTPClient
import SwiftkubeModel

public final class RolesHandler: NamespaceScopedResourceHandler {

	public typealias ResourceList = rbac.v1.RoleList
	public typealias Resource = rbac.v1.Role

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .rbacV1,
			resoucePluralName: "roles"
		)
	}
}

public final class RoleBindingsHandler: NamespaceScopedResourceHandler {

	public typealias ResourceList = rbac.v1.RoleBindingList
	public typealias Resource = rbac.v1.RoleBinding

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .rbacV1,
			resoucePluralName: "rolebindings"
		)
	}
}

public final class ClusterRolesHandler: ClusterScopedResourceHandler {

	public typealias ResourceList = rbac.v1.ClusterRoleList
	public typealias Resource = rbac.v1.ClusterRole

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .rbacV1,
			resoucePluralName: "clusterroles"
		)
	}
}

public final class ClusterRoleBindingsHandler: ClusterScopedResourceHandler {

	public typealias ResourceList = rbac.v1.ClusterRoleBindingList
	public typealias Resource = rbac.v1.ClusterRoleBinding

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .rbacV1,
			resoucePluralName: "clusterrolebindings"
		)
	}
}
