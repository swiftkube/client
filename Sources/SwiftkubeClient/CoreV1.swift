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

public final class ConfigMapsHandler: NamespaceScopedResourceHandler {

	public typealias ResourceList = core.v1.ConfigMapList
	public typealias Resource = core.v1.ConfigMap

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .coreV1,
			resoucePluralName: "configmaps"
		)
	}
}

public final class NamespacesHandler: ClusterScopedResourceHandler {

	public typealias ResourceList = core.v1.NamespaceList
	public typealias Resource = core.v1.Namespace

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .coreV1,
			resoucePluralName: "namespaces"
		)
	}
}

public final class NodesHandler: ClusterScopedResourceHandler {

	public typealias ResourceList = core.v1.NodeList
	public typealias Resource = core.v1.Node

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .coreV1,
			resoucePluralName: "nodes"
		)
	}
}

public final class PodsHandler: NamespaceScopedResourceHandler {

	public typealias ResourceList = core.v1.PodList
	public typealias Resource = core.v1.Pod

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .coreV1,
			resoucePluralName: "pods"
		)
	}
}

public final class SecretsHandler: NamespaceScopedResourceHandler {

	public typealias ResourceList = core.v1.SecretList
	public typealias Resource = core.v1.Secret

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .coreV1,
			resoucePluralName: "secrets"
		)
	}
}

public final class ServicesHandler: NamespaceScopedResourceHandler {

	public typealias ResourceList = core.v1.ServiceList
	public typealias Resource = core.v1.Service

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .coreV1,
			resoucePluralName: "services"
		)
	}
}
