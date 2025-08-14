//
// Copyright 2025 Swiftkube Project
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
import NIOSSL
import Yams

extension KubernetesClientConfig {

	/// Initializes a client configuration.
	///
	/// This factory method tries to resolve a `kube config` automatically from  different sources in the following order:
	///
	/// - A Kube config file at path of environment variable `KUBECONFIG` (if set)
	/// - A Kube config file in the user's `$HOME/.kube/config` directory
	/// - `ServiceAccount` token located at `/var/run/secrets/kubernetes.io/serviceaccount/token` and a mounted CA certificate, if it's running in Kubernetes.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will  default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default  to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func initialize(
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? = nil,
		logger: Logger?
	) throws -> KubernetesClientConfig? {
		guard
			let kubeConfig = try KubeConfig.fromEnvironment()
				?? KubeConfig.fromDefaultLocalConfig()
				?? KubeConfig.fromServiceAccount()
		else {
			return nil
		}

		return try from(
			kubeConfig: kubeConfig,
			contextName: nil,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration,
			logger: logger
		)
	}

	/// Initializes a client configuration from a given KubeConfig using the specified `current-context`.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - kubeConfig: The KubeConfig previously created, will use the current context as set in KubeConfig
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout wil  default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default  to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func from(
		kubeConfig: KubeConfig,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? = nil,
		logger: Logger?
	) throws -> KubernetesClientConfig? {
		return try from(
			kubeConfig: kubeConfig,
			contextName: nil,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration,
			logger: logger
		)
	}

	/// Initializes a client configuration from a given KubeConfig for the specified Kubernetes context name.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - kubeConfig: The KubeConfig previously created
	///   - contextName: The specific context within the KubeConfig to use
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default  to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func from(
		kubeConfig: KubeConfig,
		contextName: String?,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? = nil,
		logger: Logger?
	) throws -> KubernetesClientConfig? {
		guard let targetContext = contextName ?? kubeConfig.currentContext else {
			return nil
		}

		guard let context = kubeConfig.contexts?.filter({ $0.name == targetContext }).map(\.context).first else {
			return nil
		}

		guard let cluster = kubeConfig.clusters?.filter({ $0.name == context.cluster }).map(\.cluster).first else {
			return nil
		}

		guard let masterURL = URL(string: cluster.server) else {
			return nil
		}

		guard let authInfo = kubeConfig.users?.filter({ $0.name == context.user }).map(\.authInfo).first else {
			return nil
		}

		guard let authentication = authInfo.authentication(logger: logger) else {
			return nil
		}

		let timeout = timeout ?? .init()
		let redirectConfiguration = redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return KubernetesClientConfig(
			masterURL: masterURL,
			namespace: context.namespace ?? "default",
			authentication: authentication,
			trustRoots: cluster.trustRoots(logger: logger),
			insecureSkipTLSVerify: cluster.insecureSkipTLSVerify ?? true,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration,
			proxyURL: cluster.proxyURL.flatMap { URL(string: $0) }
		)
	}
}
