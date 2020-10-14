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
import Foundation
import Logging
import NIO
import NIOHTTP1
import NIOSSL
import SwiftkubeModel

public enum SwiftkubeAPIError: Error {
	case invalidURL
	case badRequest(String)
	case emptyResponse
	case decodingError(String)
	case requestError(meta.v1.Status)
}

public class KubernetesClient {

	internal static let loggingDisabled = Logger(label: "SKC-do-not-log", factory: { _ in SwiftLogNoOpLogHandler() })

	public let config: KubernetesClientConfig
	private let httpClient: HTTPClient
	private let logger: Logger

	public convenience init?(provider: HTTPClient.EventLoopGroupProvider = .createNew, logger: Logger? = nil) {
		let logger = logger ?? KubernetesClient.loggingDisabled

		guard
			let config =
				(try? LocalFileConfigLoader().load(logger: logger)) ??
				(try? ServiceAccountConfigLoader().load(logger: logger))
		else {
			return nil
		}

		self.init(config: config, provider: provider, logger: logger)
	}

	public init(config: KubernetesClientConfig, provider: HTTPClient.EventLoopGroupProvider = .createNew, logger: Logger? = nil) {
		self.config = config
		self.logger = logger ?? KubernetesClient.loggingDisabled

		var tlsConfiguration = TLSConfiguration.forClient(
			minimumTLSVersion: .tlsv12,
			certificateVerification: .fullVerification
		)

		tlsConfiguration.trustRoots = self.config.trustRoots

		if case let KubernetesClientAuthentication.x509(clientCertificate, clientKey) = self.config.authentication {
			tlsConfiguration.certificateChain = [.certificate(clientCertificate)]
			tlsConfiguration.privateKey = NIOSSLPrivateKeySource.privateKey(clientKey)
		}

		self.httpClient = HTTPClient(
			eventLoopGroupProvider: provider,
			configuration: HTTPClient.Configuration(
				tlsConfiguration: tlsConfiguration,
				redirectConfiguration: .follow(max: 10, allowCycles: false),
				timeout: .init(connect: .seconds(1))
			)
		)
	}

	deinit {
		try? httpClient.syncShutdown()
	}
}

public extension KubernetesClient {

	var clusterRoles: ClusterScopedGenericKubernetesClient<rbac.v1.ClusterRole> {
		clusterScoped(for: rbac.v1.ClusterRole.self)
	}

	var clusterRoleBindings: ClusterScopedGenericKubernetesClient<rbac.v1.ClusterRoleBinding> {
		clusterScoped(for: rbac.v1.ClusterRoleBinding.self)
	}

	var configMaps: NamespacedGenericKubernetesClient<core.v1.ConfigMap> {
		namespaced(for: core.v1.ConfigMap.self)
	}

	var daemonSets: ClusterScopedGenericKubernetesClient<apps.v1.DaemonSet> {
		clusterScoped(for: apps.v1.DaemonSet.self)
	}

	var deployments: NamespacedGenericKubernetesClient<apps.v1.Deployment> {
		namespaced(for: apps.v1.Deployment.self)
	}

	var events: NamespacedGenericKubernetesClient<core.v1.Event> {
		namespaced(for: core.v1.Event.self)
	}

	var ingresses: NamespacedGenericKubernetesClient<networking.v1beta1.Ingress> {
		namespaced(for: networking.v1beta1.Ingress.self)
	}

	var namespaces: ClusterScopedGenericKubernetesClient<core.v1.Namespace> {
		clusterScoped(for: core.v1.Namespace.self)
	}

	var nodes: ClusterScopedGenericKubernetesClient<core.v1.Node> {
		clusterScoped(for: core.v1.Node.self)
	}

	var pods: NamespacedGenericKubernetesClient<core.v1.Pod> {
		namespaced(for: core.v1.Pod.self)
	}

	var roles: NamespacedGenericKubernetesClient<rbac.v1.Role> {
		namespaced(for: rbac.v1.Role.self)
	}

	var roleBindings: NamespacedGenericKubernetesClient<rbac.v1.RoleBinding> {
		namespaced(for: rbac.v1.RoleBinding.self)
	}

	var secrets: NamespacedGenericKubernetesClient<core.v1.Secret> {
		namespaced(for: core.v1.Secret.self)
	}

	var services: NamespacedGenericKubernetesClient<core.v1.Service> {
		namespaced(for: core.v1.Service.self)
	}

	var statefulSets: NamespacedGenericKubernetesClient<apps.v1.StatefulSet> {
		namespaced(for: apps.v1.StatefulSet.self)
	}
}

public extension KubernetesClient {

	func `for`<R: KubernetesAPIResource>(_ type: R.Type) -> GenericKubernetesClient<R> {
		return GenericKubernetesClient<R>(httpClient: self.httpClient, config: self.config, logger: logger)
	}

	func clusterScoped<R: KubernetesAPIResource>(for type: R.Type) -> ClusterScopedGenericKubernetesClient<R> {
		return ClusterScopedGenericKubernetesClient<R>(httpClient: self.httpClient, config: self.config, logger: logger)
	}

	func namespaced<R: KubernetesAPIResource>(for type: R.Type) -> NamespacedGenericKubernetesClient<R> {
		return NamespacedGenericKubernetesClient<R>(httpClient: self.httpClient, config: self.config, logger: logger)
	}
}
