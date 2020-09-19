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
import NIO
import NIOSSL
import SwiftkubeModel

public enum KubernetesClientAuthentication {
	case basicAuth(username: String, password: String)
	case bearer(token: String)
	case x509(clientCertificate: NIOSSLCertificate, clientKey: NIOSSLPrivateKey)

	internal func authorizationHeader() -> String? {
		switch self {
		case let .basicAuth(username: username, password: password):
			return HTTPClient.Authorization.basic(username: username, password: password).headerValue
		case let .bearer(token: token):
			return HTTPClient.Authorization.bearer(tokens: token).headerValue
		default:
			return nil
		}
	}
}

public class KubernetesClient {

	public let config: KubernetesClientConfig
	private let httpClient: HTTPClient

	public convenience init?(provider: HTTPClient.EventLoopGroupProvider = .createNew) {
		guard
			let config = (try? LocalFileConfigLoader().load()) ?? (try? ServiceAccountConfigLoader().load())
		else {
			return nil
		}

		self.init(config: config, provider: provider)
	}

	public init(config: KubernetesClientConfig, provider: HTTPClient.EventLoopGroupProvider = .createNew) {
		self.config = config

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

	public lazy var clusterRole = ClusterRolesHandler(httpClient: self.httpClient, config: self.config)
	public lazy var clusterRoleBindings = ClusterRoleBindingsHandler(httpClient: self.httpClient, config: self.config)
	public lazy var configMaps = ConfigMapsHandler(httpClient: self.httpClient, config: self.config)
	public lazy var deployments = DeploymentsHandler(httpClient: self.httpClient, config: self.config)
	public lazy var namespaces = NamespacesHandler(httpClient: self.httpClient, config: self.config)
	public lazy var nodes = NodesHandler(httpClient: self.httpClient, config: self.config)
	public lazy var pods = PodsHandler(httpClient: self.httpClient, config: self.config)
	public lazy var roles = RolesHandler(httpClient: self.httpClient, config: self.config)
	public lazy var roleBindings = RoleBindingsHandler(httpClient: self.httpClient, config: self.config)
	public lazy var secrets = SecretsHandler(httpClient: self.httpClient, config: self.config)
	public lazy var services = ServicesHandler(httpClient: self.httpClient, config: self.config)

	deinit {
		try? httpClient.syncShutdown()
	}
}
