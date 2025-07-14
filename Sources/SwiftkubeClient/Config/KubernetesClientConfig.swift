//
// Copyright 2020 Swiftkube Project
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

// MARK: - KubernetesClientConfig

/// Configuration object for the ``KubernetesClient``
public struct KubernetesClientConfig: Sendable {

	/// The URL for the kuberentes API server.
	public let masterURL: URL
	/// The namespace for the current client context.
	public let namespace: String
	/// The ``KubernetesClientAuthentication`` scheme.
	public let authentication: KubernetesClientAuthentication
	/// NIOSSL trust store sources fot the client.
	public let trustRoots: NIOSSLTrustRoots?
	/// Skips TLS verification for all API requests.
	public let insecureSkipTLSVerify: Bool
	/// The default timeout configuration for the underlying `HTTPClient`.
	public let timeout: HTTPClient.Configuration.Timeout
	/// The default redirect configuration for the underlying `HTTPCLient`.
	public let redirectConfiguration:
		HTTPClient.Configuration.RedirectConfiguration
	/// URL to the proxy to be used for all requests made by this client.
	public let proxyURL: URL?
	/// Whether to request and decode gzipped responses from the API server.
	public let gzip: Bool

	public init(
		masterURL: URL,
		namespace: String,
		authentication: KubernetesClientAuthentication,
		trustRoots: NIOSSLTrustRoots?,
		insecureSkipTLSVerify: Bool,
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration,
		proxyURL: URL? = nil,
		gzip: Bool = false
	) {
		self.masterURL = masterURL
		self.namespace = namespace
		self.authentication = authentication
		self.trustRoots = trustRoots
		self.insecureSkipTLSVerify = insecureSkipTLSVerify
		self.timeout = timeout
		self.redirectConfiguration = redirectConfiguration
		self.proxyURL = proxyURL
		self.gzip = gzip
	}
}

extension KubernetesClientConfig {
	/// Initializes a client configuration from a given KubeConfigLoader.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - configLoader: The KubeConfigLoader to use to load the KubeConfig
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will
	/// default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default
	/// to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func createFromKubeConfigLoader(
		configLoader: KubeConfigLoader,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? =
			nil,
		logger: Logger = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration =
			redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return try? KubeConfigKubernetesClientConfigLoader(
			configLoader: configLoader
		)
		.forCurrentContext(
			logger: logger,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration
		)
	}

	/// Initializes a client configuration from a given KubeConfigLoader.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - configLoader: The KubeConfigLoader to use to load the KubeConfig
	///   - context: The specific Kubernetes context to use
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will
	/// default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default
	/// to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func createFromKubeConfigLoaderForContext(
		configLoader: KubeConfigLoader,
		context: String,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? =
			nil,
		logger: Logger = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration =
			redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return try? KubeConfigKubernetesClientConfigLoader(
			configLoader: configLoader
		)
		.forContext(
			context: context,
			logger: logger,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration
		)
	}

	/// Initializes a client configuration.
	///
	/// This factory method tries to resolve a `kube config` automatically from
	/// different sources in the following order:
	///
	/// - A Kube config file in the user's `$HOME/.kube/config` directory
	/// - `ServiceAccount` token located at `/var/run/secrets/kubernetes.io/serviceaccount/token` and a mounted CA certificate, if it's running in Kubernetes.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will
	/// default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default
	/// to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func initialize(
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? =
			nil,
		logger: Logger? = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration =
			redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return
			createFromKubeConfigLoader(configLoader: LocalKubeConfigLoader())
			?? (try? ServiceAccountConfigLoader().load(
				timeout: timeout,
				redirectConfiguration: redirectConfiguration,
				logger: logger
			))
	}

	/// Initializes a client configuration.
	///
	/// This factory method tries to resolve a `kube config` automatically from
	/// different sources in the following order:
	///
	/// - A Kube config file in the user's `$HOME/.kube/config` directory
	/// - `ServiceAccount` token located at `/var/run/secrets/kubernetes.io/serviceaccount/token` and a mounted CA certificate, if it's running in Kubernetes.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will
	/// default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default
	/// to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func initialize(
		context: String,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? =
			nil,
		logger: Logger? = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration =
			redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return
			createFromKubeConfigLoaderForContext(
				configLoader: LocalKubeConfigLoader(),
				context: context
			)
			?? (try? ServiceAccountConfigLoader().load(
				timeout: timeout,
				redirectConfiguration: redirectConfiguration,
				logger: logger
			))
	}

	/// Initializes a client configuration from a given URL.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - url: The url to load the configuration from. It can be a local file or remote URL.
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will
	/// default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default
	/// to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func create(
		fromUrl url: URL,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? =
			nil,
		logger: Logger = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration =
			redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return createFromKubeConfigLoader(
			configLoader: URLConfigLoader(url: url),
			timeout: timeout,
			redirectConfiguration: redirectConfiguration,
			logger: logger
		)
	}

	/// Initializes a client configuration from a given String.
	///
	/// It is also possible to override the default values for the underlying `HTTPClient` timeout and redirect config.
	///
	/// - Parameters:
	///   - string: The string to load the configuration from.
	///   - timeout: The desired timeout configuration to apply. If not provided, then `connect` timeout will
	/// default to 10 seconds.
	///   - redirectConfiguration: Specifies redirect processing settings. If not provided, then it will default
	/// to a maximum of 5 follows w/o cycles.
	///   - logger: The logger to use for the underlying configuration loaders.
	/// - Returns: An instance of KubernetesClientConfig for the Swiftkube KubernetesClient
	public static func createFromString(
		fromString string: String,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? =
			nil,
		logger: Logger = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration =
			redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return createFromKubeConfigLoader(
			configLoader: StringConfigLoader(contents: string),
			timeout: timeout,
			redirectConfiguration: redirectConfiguration,
			logger: logger
		)
	}
}

// MARK: - KubeConfigLoader

public protocol KubeConfigLoader {
	func load(logger: Logger?) throws -> KubeConfig?
}

struct KubeConfigKubernetesClientConfigLoader {
	let configLoader: KubeConfigLoader

	func forContext(
		context: String,
		logger: Logger?,
		timeout: HTTPClient.Configuration.Timeout = .init(),
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration =
			.follow(max: 10, allowCycles: false),
	) throws -> KubernetesClientConfig? {
		return try configLoader.load(logger: logger).flatMap({ config in
			kubeToClientConfig(
				contextSelector: contextSelector(context: context),
				logger: logger,
				timeout: timeout,
				redirectConfiguration: redirectConfiguration
			)(config)
		})
	}

	func forCurrentContext(
		logger: Logger?,
		timeout: HTTPClient.Configuration.Timeout = .init(),
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration =
			.follow(max: 10, allowCycles: false),
	) throws -> KubernetesClientConfig? {
		return try configLoader.load(logger: logger).flatMap({ config in
			kubeToClientConfig(
				contextSelector: currentContextSelector,
				logger: logger,
				timeout: timeout,
				redirectConfiguration: redirectConfiguration
			)(config)
		})
	}

	internal func currentContextSelector(
		namedContext: NamedContext,
		kubeConfig: KubeConfig
	) -> Bool {
		namedContext.name == kubeConfig.currentContext
	}

	internal func contextSelector(context: String) -> (NamedContext, KubeConfig)
		-> Bool
	{
		return { namedContext, _ in
			namedContext.name == context
		}
	}

	internal func kubeToClientConfig(
		contextSelector: @escaping (NamedContext, KubeConfig) -> Bool,
		logger: Logger?,
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration,
	) -> (KubeConfig) -> KubernetesClientConfig? {
		return { kubeConfig in
			guard
				let context = kubeConfig.contexts?.filter({
					contextSelector($0, kubeConfig)
				}).map(\.context).first
			else {
				return nil
			}

			guard
				let cluster = kubeConfig.clusters?.filter({
					$0.name == context.cluster
				}).map(\.cluster).first
			else {
				return nil
			}

			guard let masterURL = URL(string: cluster.server) else {
				return nil
			}

			guard
				let authInfo = kubeConfig.users?.filter({
					$0.name == context.user
				}).map(\.authInfo).first
			else {
				return nil
			}

			guard let authentication = authInfo.authentication(logger: logger)
			else {
				return nil
			}

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
}

// MARK: - StringConfigLoader

internal struct StringConfigLoader: KubeConfigLoader {
	let contents: String

	func load(logger: Logging.Logger?) throws -> KubeConfig? {
		let decoder = YAMLDecoder()

		return try? decoder.decode(KubeConfig.self, from: contents)
	}
}

// MARK: - URLConfigLoader

internal struct URLConfigLoader: KubeConfigLoader {
	let url: URL

	func load(logger: Logging.Logger?) throws -> KubeConfig? {
		guard let contents = try? String(contentsOf: url, encoding: .utf8)
		else {
			return nil
		}

		return try? StringConfigLoader(contents: contents).load(logger: logger)
	}
}

// MARK: - LocalKubeConfigLoader

internal struct LocalKubeConfigLoader: KubeConfigLoader {
	func load(logger: Logging.Logger?) throws -> KubeConfig? {
		var kubeConfigURL: URL?

		if let kubeConfigPath = ProcessInfo.processInfo.environment[
			"KUBECONFIG"
		] {
			kubeConfigURL = URL(fileURLWithPath: kubeConfigPath)
		} else if let homePath = ProcessInfo.processInfo.environment["HOME"] {
			kubeConfigURL = URL(fileURLWithPath: homePath + "/.kube/config")
		}

		guard let kubeConfigURL else {
			logger?.warning(
				"Skipping local kubeconfig loading, neither environment variable KUBECONFIG nor HOME are set."
			)
			return nil
		}
		logger?.info("Loading configuration from \(kubeConfigURL)")

		return try? URLConfigLoader(url: kubeConfigURL).load(logger: logger)
	}
}

// MARK: - ServiceAccountConfigLoader

internal struct ServiceAccountConfigLoader {

	internal func load(
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration,
		logger: Logger?
	) throws -> KubernetesClientConfig? {
		guard
			let masterHost = ProcessInfo.processInfo.environment[
				"KUBERNETES_SERVICE_HOST"
			],
			let masterPort = ProcessInfo.processInfo.environment[
				"KUBERNETES_SERVICE_PORT"
			]
		else {
			logger?.warning(
				"Skipping service account kubeconfig because either KUBERNETES_SERVICE_HOST or KUBERNETES_SERVICE_PORT is not set"
			)
			return nil
		}

		guard let masterURL = buildMasterURL(host: masterHost, port: masterPort)
		else {
			logger?.warning(
				"Could not construct master URL from host: \(masterHost) and port: \(masterPort)"
			)
			return nil
		}

		let namespaceFile = URL(
			fileURLWithPath:
				"/var/run/secrets/kubernetes.io/serviceaccount/namespace"
		)
		let namespace = try? String(contentsOf: namespaceFile, encoding: .utf8)

		if namespace == nil {
			logger?.debug(
				"Did not find service account namespace at /var/run/secrets/kubernetes.io/serviceaccount/namespace"
			)
		}

		let tokenFile = URL(
			fileURLWithPath:
				"/var/run/secrets/kubernetes.io/serviceaccount/token"
		)
		guard let token = try? String(contentsOf: tokenFile, encoding: .utf8)
		else {
			logger?.warning(
				"Did not find service account token at /var/run/secrets/kubernetes.io/serviceaccount/token"
			)
			return nil
		}

		let caFile = URL(
			fileURLWithPath:
				"/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
		)
		let trustRoots = loadTrustRoots(caFile: caFile, logger: logger)

		return KubernetesClientConfig(
			masterURL: masterURL,
			namespace: namespace ?? "default",
			authentication: KubernetesClientAuthentication.bearer(token: token),
			trustRoots: trustRoots,
			insecureSkipTLSVerify: trustRoots == nil,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration,
			proxyURL: nil
		)
	}

	private func buildMasterURL(host: String, port: String) -> URL? {
		if host.contains(":") {
			return URL(string: "https://[\(host)]:\(port)")
		} else {
			return URL(string: "https://\(host):\(port)")
		}
	}

	private func loadTrustRoots(caFile: URL, logger: Logger?)
		-> NIOSSLTrustRoots?
	{
		guard
			let caData = try? Data(contentsOf: caFile),
			let certificates = try? NIOSSLCertificate.fromPEMBytes(
				[UInt8](caData)
			)
		else {
			logger?.warning(
				"Could not load service account ca cert at /var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
			)
			return nil
		}

		return NIOSSLTrustRoots.certificates(certificates)
	}
}

extension Cluster {

	fileprivate func trustRoots(logger: Logger?) -> NIOSSLTrustRoots? {
		do {
			if let caFile = certificateAuthority {
				let certificates = try NIOSSLCertificate.fromPEMFile(caFile)
				return NIOSSLTrustRoots.certificates(certificates)
			}

			if let caData = certificateAuthorityData {
				let certificates = try NIOSSLCertificate.fromPEMBytes(
					[UInt8](caData)
				)
				return NIOSSLTrustRoots.certificates(certificates)
			}
		} catch {
			logger?.warning(
				"Error loading certificate authority for cluster \(server): \(error)"
			)
		}
		return nil
	}
}

extension AuthInfo {

	public func authentication(logger: Logger?)
		-> KubernetesClientAuthentication?
	{
		if let username = username, let password = password {
			return .basicAuth(username: username, password: password)
		}

		if let token = token {
			return .bearer(token: token)
		}

		do {
			if let tokenFile = tokenFile {
				let fileURL = URL(fileURLWithPath: tokenFile)
				let token = try String(contentsOf: fileURL, encoding: .utf8)
				return .bearer(token: token)
			}
		} catch {
			logger?.warning(
				"Error initializing authentication from token file \(String(describing: tokenFile)): \(error)"
			)
		}

		do {
			if let clientCertificateFile = clientCertificate,
				let clientKeyFile = clientKey
			{
				let clientCertificate = try NIOSSLCertificate(
					file: clientCertificateFile,
					format: .pem
				)
				let clientKey = try NIOSSLPrivateKey(
					file: clientKeyFile,
					format: .pem
				)
				return .x509(
					clientCertificate: clientCertificate,
					clientKey: clientKey
				)
			}

			if let clientCertificateData = clientCertificateData,
				let clientKeyData = clientKeyData
			{
				let clientCertificate = try NIOSSLCertificate(
					bytes: [UInt8](clientCertificateData),
					format: .pem
				)
				let clientKey = try NIOSSLPrivateKey(
					bytes: [UInt8](clientKeyData),
					format: .pem
				)
				return .x509(
					clientCertificate: clientCertificate,
					clientKey: clientKey
				)
			}
		} catch {
			logger?.warning(
				"Error initializing authentication from client certificate: \(error)"
			)
		}

		#if os(Linux) || os(macOS)
			do {
				if let exec {
					let outputData = try run(
						command: exec.command,
						arguments: exec.args
					)

					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .iso8601
					let credential = try decoder.decode(
						ExecCredential.self,
						from: outputData
					)

					return .bearer(token: credential.status.token)
				}
			} catch {
				logger?.warning(
					"Error initializing authentication from exec \(error)"
				)
			}
		#endif
		return nil
	}
}

// MARK: - ExecCredential

// It seems that AWS doesn't implement properly the model for client.authentication.k8s.io/v1beta1
// Acordingly with the doc https://kubernetes.io/docs/reference/config-api/client-authentication.v1beta1/
// ExecCredential.Spec.interactive is required as long as the ones in the Status object.
public struct ExecCredential: Codable {
	let apiVersion: String
	let kind: String
	let spec: Spec
	let status: Status
}

extension ExecCredential {
	public struct Spec: Codable {
		let cluster: Cluster?
		let interactive: Bool?
	}

	public struct Status: Codable {
		let expirationTimestamp: Date
		let token: String
		let clientCertificateData: String?
		let clientKeyData: String?
	}
}

#if os(Linux) || os(macOS)
	internal func run(command: String, arguments: [String]? = nil) throws
		-> Data
	{
		func run(_ command: String, _ arguments: [String]?) throws -> Data {
			let task = Process()
			task.executableURL = URL(fileURLWithPath: command)
			arguments.flatMap { task.arguments = $0 }

			let pipe = Pipe()
			task.standardOutput = pipe

			try task.run()

			return pipe.fileHandleForReading.availableData
		}

		func resolve(command: String) throws -> String {
			try String(
				decoding:
					run("/usr/bin/which", ["\(command)"]),
				as: UTF8.self
			).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		return try run(resolve(command: command), arguments)
	}
#endif
