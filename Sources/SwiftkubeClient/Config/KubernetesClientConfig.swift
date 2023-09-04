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
public struct KubernetesClientConfig {

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
	public let redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration

	public init(
		masterURL: URL,
		namespace: String,
		authentication: KubernetesClientAuthentication,
		trustRoots: NIOSSLTrustRoots?,
		insecureSkipTLSVerify: Bool,
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration
	) {
		self.masterURL = masterURL
		self.namespace = namespace
		self.authentication = authentication
		self.trustRoots = trustRoots
		self.insecureSkipTLSVerify = insecureSkipTLSVerify
		self.timeout = timeout
		self.redirectConfiguration = redirectConfiguration
	}
}

public extension KubernetesClientConfig {

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
	static func initialize(
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? = nil,
		logger: Logger? = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration = redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return
			(try? LocalKubeConfigLoader().load(timeout: timeout, redirectConfiguration: redirectConfiguration, logger: logger)) ??
			(try? ServiceAccountConfigLoader().load(timeout: timeout, redirectConfiguration: redirectConfiguration, logger: logger))
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
	static func create(
		fromUrl url: URL,
		timeout: HTTPClient.Configuration.Timeout? = nil,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration? = nil,
		logger: Logger = SwiftkubeClient.loggingDisabled
	) -> KubernetesClientConfig? {
		let timeout = timeout ?? .init()
		let redirectConfiguration = redirectConfiguration ?? .follow(max: 5, allowCycles: false)

		return try? URLConfigLoader(url: url).load(timeout: timeout, redirectConfiguration: redirectConfiguration, logger: logger)
	}
}

// MARK: - KubernetesClientConfigLoader

internal protocol KubernetesClientConfigLoader {

	func load(
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration,
		logger: Logger?
	) throws -> KubernetesClientConfig?
}

extension KubernetesClientConfigLoader {
	func load(logger: Logger?) throws -> KubernetesClientConfig? {
		try load(timeout: .init(), redirectConfiguration: .follow(max: 10, allowCycles: false), logger: logger)
	}
}

// MARK: - URLConfigLoader

internal struct URLConfigLoader: KubernetesClientConfigLoader {

	let url: URL

	internal func load(
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration,
		logger: Logger?
	) throws -> KubernetesClientConfig? {
		let decoder = YAMLDecoder()

		guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
			return nil
		}

		guard let kubeConfig = try? decoder.decode(KubeConfig.self, from: contents) else {
			return nil
		}

		guard let currentContext = kubeConfig.currentContext else {
			return nil
		}

		guard let context = kubeConfig.contexts?.filter({ $0.name == currentContext }).map(\.context).first else {
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

		return KubernetesClientConfig(
			masterURL: masterURL,
			namespace: context.namespace ?? "default",
			authentication: authentication,
			trustRoots: cluster.trustRoots(logger: logger),
			insecureSkipTLSVerify: cluster.insecureSkipTLSVerify ?? true,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration
		)
	}
}

// MARK: - LocalKubeConfigLoader

internal struct LocalKubeConfigLoader: KubernetesClientConfigLoader {

	func load(
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration,
		logger: Logger?
	) throws -> KubernetesClientConfig? {
		guard let homePath = ProcessInfo.processInfo.environment["HOME"] else {
			logger?.info("Skipping kubeconfig in $HOME/.kube/config because HOME env variable is not set.")
			return nil
		}

		let kubeConfigURL = URL(fileURLWithPath: homePath + "/.kube/config")
		return try? URLConfigLoader(url: kubeConfigURL)
			.load(timeout: timeout, redirectConfiguration: redirectConfiguration, logger: logger)
	}
}

// MARK: - ServiceAccountConfigLoader

internal struct ServiceAccountConfigLoader: KubernetesClientConfigLoader {

	internal func load(
		timeout: HTTPClient.Configuration.Timeout,
		redirectConfiguration: HTTPClient.Configuration.RedirectConfiguration,
		logger: Logger?
	) throws -> KubernetesClientConfig? {
		guard
			let masterHost = ProcessInfo.processInfo.environment["KUBERNETES_SERVICE_HOST"],
			let masterPort = ProcessInfo.processInfo.environment["KUBERNETES_SERVICE_PORT"]
		else {
			logger?.warning("Skipping service account kubeconfig because either KUBERNETES_SERVICE_HOST or KUBERNETES_SERVICE_PORT is not set")
			return nil
		}

		guard let masterURL = buildMasterURL(host: masterHost, port: masterPort) else {
			logger?.warning("Could not construct master URL from host: \(masterHost) and port: \(masterPort)")
			return nil
		}

		let namespaceFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/namespace")
		let namespace = try? String(contentsOf: namespaceFile, encoding: .utf8)

		if namespace == nil {
			logger?.debug("Did not find service account namespace at /var/run/secrets/kubernetes.io/serviceaccount/namespace")
		}

		let tokenFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/token")
		guard let token = try? String(contentsOf: tokenFile, encoding: .utf8) else {
			logger?.warning("Did not find service account token at /var/run/secrets/kubernetes.io/serviceaccount/token")
			return nil
		}

		let caFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
		let trustRoots = loadTrustRoots(caFile: caFile, logger: logger)

		return KubernetesClientConfig(
			masterURL: masterURL,
			namespace: namespace ?? "default",
			authentication: KubernetesClientAuthentication.bearer(token: token),
			trustRoots: trustRoots,
			insecureSkipTLSVerify: trustRoots == nil,
			timeout: timeout,
			redirectConfiguration: redirectConfiguration
		)
	}

	private func buildMasterURL(host: String, port: String) -> URL? {
		if host.contains(":") {
			return URL(string: "https://[\(host)]:\(port)")
		} else {
			return URL(string: "https://\(host):\(port)")
		}
	}

	private func loadTrustRoots(caFile: URL, logger: Logger?) -> NIOSSLTrustRoots? {
		guard
			let caData = try? Data(contentsOf: caFile),
			let certificates = try? NIOSSLCertificate.fromPEMBytes([UInt8](caData))
		else {
			logger?.warning("Could not load service account ca cert at /var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
			return nil
		}

		return NIOSSLTrustRoots.certificates(certificates)
	}
}

private extension Cluster {

	func trustRoots(logger: Logger?) -> NIOSSLTrustRoots? {
		do {
			if let caFile = certificateAuthority {
				let certificates = try NIOSSLCertificate.fromPEMFile(caFile)
				return NIOSSLTrustRoots.certificates(certificates)
			}

			if let caData = certificateAuthorityData {
				let certificates = try NIOSSLCertificate.fromPEMBytes([UInt8](caData))
				return NIOSSLTrustRoots.certificates(certificates)
			}
		} catch {
			logger?.warning("Error loading certificate authority for cluster \(server): \(error)")
		}
		return nil
	}
}

private extension AuthInfo {

	func authentication(logger: Logger?) -> KubernetesClientAuthentication? {
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
			logger?.warning("Error initializing authentication from token file \(String(describing: tokenFile)): \(error)")
		}

		do {
			if let clientCertificateFile = clientCertificate, let clientKeyFile = clientKey {
				let clientCertificate = try NIOSSLCertificate(file: clientCertificateFile, format: .pem)
				let clientKey = try NIOSSLPrivateKey(file: clientKeyFile, format: .pem)
				return .x509(clientCertificate: clientCertificate, clientKey: clientKey)
			}

			if let clientCertificateData = clientCertificateData, let clientKeyData = clientKeyData {
				let clientCertificate = try NIOSSLCertificate(bytes: [UInt8](clientCertificateData), format: .pem)
				let clientKey = try NIOSSLPrivateKey(bytes: [UInt8](clientKeyData), format: .pem)
				return .x509(clientCertificate: clientCertificate, clientKey: clientKey)
			}
		} catch {
			logger?.warning("Error initializing authentication from client certificate: \(error)")
		}

		#if os(Linux) || os(macOS)
			do {
				if let exec {
					let outputData = try run(command: exec.command, arguments: exec.args)

					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .iso8601
					let credential = try decoder.decode(ExecCredential.self, from: outputData)

					return .bearer(token: credential.status.token)
				}
			} catch {
				logger?.warning("Error initializing authentication from exec \(error)")
			}
		#endif
		return nil
	}
}

// MARK: - ExecCredential

// It seems that AWS doesn't implement properly the model for client.authentication.k8s.io/v1beta1
// Acordingly with the doc https://kubernetes.io/docs/reference/config-api/client-authentication.v1beta1/
// ExecCredential.Spec.interactive is required as long as the ones in the Status object.
internal struct ExecCredential: Decodable {
	let apiVersion: String
	let kind: String
	let spec: Spec
	let status: Status
}

internal extension ExecCredential {
	struct Spec: Decodable {
		let cluster: Cluster?
		let interactive: Bool?
	}

	struct Status: Decodable {
		let expirationTimestamp: Date
		let token: String
		let clientCertificateData: String?
		let clientKeyData: String?
	}
}

#if os(Linux) || os(macOS)
	internal func run(command: String, arguments: [String]? = nil) throws -> Data {
		func run(_ command: String, _ arguments: [String]?) throws -> Data {
			let task = Process()
			task.executableURL = URL(fileURLWithPath: command)
			task.arguments = arguments

			let pipe = Pipe()
			task.standardOutput = pipe

			try task.run()

			return pipe.fileHandleForReading.availableData
		}

		func resolve(command: String) throws -> String {
			try String(decoding:
				run("/usr/bin/which", ["\(command)"]), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
		}

		return try run(resolve(command: command), arguments)
	}
#endif
