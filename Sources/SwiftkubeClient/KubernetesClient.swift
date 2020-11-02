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

	internal static func methodNotAllowed(_ method: HTTPMethod) -> SwiftkubeAPIError {
		let status = sk.status {
			$0.code = 405
			$0.status = "Failure"
			$0.reason = "MethodNotAllowed"
			$0.message = "\(method) is not supported for this resource"
		}

		return SwiftkubeAPIError.requestError(status)
	}
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

	func `for`<R: KubernetesAPIResource>(_ type: R.Type) -> GenericKubernetesClient<R> {
		return GenericKubernetesClient<R>(httpClient: self.httpClient, config: self.config, logger: logger)
	}

	func `for`(gvk: GroupVersionKind) -> GenericKubernetesClient<AnyKubernetesAPIResource> {
		return GenericKubernetesClient<AnyKubernetesAPIResource>(httpClient: self.httpClient, config: self.config, gvk: gvk, logger: logger)
	}

	func clusterScoped<R: KubernetesAPIResource>(for type: R.Type) -> ClusterScopedGenericKubernetesClient<R> {
		return ClusterScopedGenericKubernetesClient<R>(httpClient: self.httpClient, config: self.config, logger: logger)
	}

	func namespaceScoped<R: KubernetesAPIResource>(for type: R.Type) -> NamespacedGenericKubernetesClient<R> {
		return NamespacedGenericKubernetesClient<R>(httpClient: self.httpClient, config: self.config, logger: logger)
	}
}

public extension KubernetesClient {

	var configMaps: NamespacedGenericKubernetesClient<core.v1.ConfigMap> {
		namespaceScoped(for: core.v1.ConfigMap.self)
	}

	var events: NamespacedGenericKubernetesClient<core.v1.Event> {
		namespaceScoped(for: core.v1.Event.self)
	}

	var namespaces: ClusterScopedGenericKubernetesClient<core.v1.Namespace> {
		clusterScoped(for: core.v1.Namespace.self)
	}

	var nodes: ClusterScopedGenericKubernetesClient<core.v1.Node> {
		clusterScoped(for: core.v1.Node.self)
	}

	var pods: NamespacedGenericKubernetesClient<core.v1.Pod> {
		namespaceScoped(for: core.v1.Pod.self)
	}

	var secrets: NamespacedGenericKubernetesClient<core.v1.Secret> {
		namespaceScoped(for: core.v1.Secret.self)
	}

	var services: NamespacedGenericKubernetesClient<core.v1.Service> {
		namespaceScoped(for: core.v1.Service.self)
	}
}
