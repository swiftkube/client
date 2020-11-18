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
import Logging
import NIOSSL
import Yams

public struct KubernetesClientConfig {
	public let masterURL: URL
	public let namespace: String
	public let authentication: KubernetesClientAuthentication
	public let trustRoots: NIOSSLTrustRoots?
	public let insecureSkipTLSVerify: Bool
}

internal protocol KubernetesClientConfigLoader {
	func load(logger: Logger) throws -> KubernetesClientConfig?
}

internal struct LocalFileConfigLoader: KubernetesClientConfigLoader {

	internal func load(logger: Logger) throws -> KubernetesClientConfig? {
		let decoder = YAMLDecoder()
		guard let homePath = ProcessInfo.processInfo.environment["HOME"] else {
			logger.info("Skipping kubeconfig in $HOME/.kube/config because HOME env variable is not set.")
			return nil
		}

		let fileURL = URL(fileURLWithPath: homePath + "/.kube/config")

		guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
			return nil
		}

		guard let kubeConfig = try? decoder.decode(KubeConfig.self, from: contents) else {
			return nil
		}

		guard let currentContext = kubeConfig.currentContext else {
			return nil
		}

		guard let context = kubeConfig.contexts?.filter({ $0.name == currentContext }).map({ $0.context }).first else {
			return nil
		}

		guard let cluster = kubeConfig.clusters?.filter({ $0.name == context.cluster }).map({ $0.cluster }).first else {
			return nil
		}

		guard let masterURL = URL(string: cluster.server) else {
			return nil
		}

		guard let authInfo = kubeConfig.users?.filter({ $0.name == context.user }).map({ $0.authInfo }).first else {
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
			insecureSkipTLSVerify: cluster.insecureSkipTLSVerify ?? true
		)
	}
}

internal struct ServiceAccountConfigLoader: KubernetesClientConfigLoader {

	internal func load(logger: Logger) throws -> KubernetesClientConfig? {
		guard
			let masterHost = ProcessInfo.processInfo.environment["KUBERNETES_SERVICE_HOST"],
			let masterPort = ProcessInfo.processInfo.environment["KUBERNETES_SERVICE_PORT"]
		else {
			logger.warning("Skipping service account kubeconfig because either KUBERNETES_SERVICE_HOST or KUBERNETES_SERVICE_PORT is not set")
			return nil
		}

		guard let masterURL = buildMasterURL(host: masterHost, port: masterPort) else {
			logger.warning("Could not construct master URL from host: \(masterHost) and port: \(masterPort)")
			return nil
		}

		let namespaceFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/namespace")
		let namespace = try? String(contentsOf: namespaceFile, encoding: .utf8)

		if namespace == nil {
			logger.debug("Did not find service account namespace at /var/run/secrets/kubernetes.io/serviceaccount/namespace")
		}

		let tokenFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/token")
		guard let token = try? String(contentsOf: tokenFile, encoding: .utf8) else {
			logger.warning("Did not find service account token at /var/run/secrets/kubernetes.io/serviceaccount/token")
			return nil
		}

		let caFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
		let trustRoots = loadTrustRoots(caFile: caFile, logger: logger)

		return KubernetesClientConfig(
			masterURL: masterURL,
			namespace: namespace ?? "default",
			authentication: KubernetesClientAuthentication.bearer(token: token),
			trustRoots: trustRoots,
			insecureSkipTLSVerify: (trustRoots == nil)
		)
	}

	private func buildMasterURL(host: String, port: String) -> URL? {
		if host.contains(":") {
			return URL(string: "https://[\(host)]:\(port)")
		} else {
			return URL(string: "https://\(host):\(port)")
		}
	}

	private func loadTrustRoots(caFile: URL, logger: Logger) -> NIOSSLTrustRoots? {
		guard
			let caData = try? Data(contentsOf: caFile),
			let certificates = try? NIOSSLCertificate.fromPEMBytes([UInt8](caData))
		else {
			logger.warning("Could not load service account ca cert at /var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
			return nil
		}

		return NIOSSLTrustRoots.certificates(certificates)
	}
}

extension Cluster {

	fileprivate func trustRoots(logger: Logger) -> NIOSSLTrustRoots? {
		do {
			if let caFile = self.certificateAuthority {
				let certificates = try NIOSSLCertificate.fromPEMFile(caFile)
				return NIOSSLTrustRoots.certificates(certificates)
			}

			if let caData = self.certificateAuthorityData {
				let certificates = try NIOSSLCertificate.fromPEMBytes([UInt8](caData))
				return NIOSSLTrustRoots.certificates(certificates)
			}
		} catch let error {
			logger.warning("Error loading certificate authority for cluster \(self.server): \(error)")
		}
		return nil
	}
}

extension AuthInfo {

	fileprivate func authentication(logger: Logger) -> KubernetesClientAuthentication? {

		if let username = self.username, let password = self.password {
			return .basicAuth(username: username, password: password)
		}

		if let token = self.token {
			return .bearer(token: token)
		}

		do {
			if let tokenFile = self.tokenFile {
				let fileURL = URL(fileURLWithPath: tokenFile)
				let token = try String(contentsOf: fileURL, encoding: .utf8)
				return .bearer(token: token)
			}
		} catch let error {
			logger.warning("Error initializing authentication from token file \(String(describing: self.tokenFile)): \(error)")
		}

		do {
			if let clientCertificateFile = self.clientCertificate, let clientKeyFile = self.clientKey {
				let clientCertificate = try NIOSSLCertificate(file: clientCertificateFile, format: .pem)
				let clientKey = try NIOSSLPrivateKey(file: clientKeyFile, format: .pem)
				return .x509(clientCertificate: clientCertificate, clientKey: clientKey)
			}

			if let clientCertificateData = self.clientCertificateData, let clientKeyData = self.clientKeyData {
				let clientCertificate = try NIOSSLCertificate(bytes: [UInt8](clientCertificateData), format: .pem)
				let clientKey = try NIOSSLPrivateKey(bytes: [UInt8](clientKeyData), format: .pem)
				return .x509(clientCertificate: clientCertificate, clientKey: clientKey)
			}
		} catch let error {
			logger.warning("Error initializing authentication from client certificate: \(error)")
		}
		return nil
	}
}
