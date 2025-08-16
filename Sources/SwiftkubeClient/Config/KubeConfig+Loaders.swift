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

import Foundation
import Logging
import Yams

public extension KubeConfig {

	static func from(config: String) throws -> KubeConfig {
		let decoder = YAMLDecoder()
		return try decoder.decode(KubeConfig.self, from: config)
	}

	static func from(url: URL) throws -> KubeConfig {
		let contents = try String(contentsOf: url, encoding: .utf8)

		return try from(config: contents)
	}

	static func fromEnvironment(envVar: String = "KUBECONFIG", logger: Logger? = nil) throws -> KubeConfig? {
		guard let varContent = ProcessInfo.processInfo.environment[envVar] else {
			logger?.info("Skipping kubeconfig because environment variable \(envVar) is not set")
			return nil
		}

		let expanded = varContent.stringByExpandingTildePath()
		let kubeConfigURL = URL(fileURLWithPath: expanded)
		logger?.info("Loading configuration from \(kubeConfigURL)")

		return try from(url: kubeConfigURL)
	}

	static func fromDefaultLocalConfig(logger: Logger? = nil) throws -> KubeConfig? {
		guard let homePath = ProcessInfo.processInfo.environment["HOME"] else {
			logger?.info("Skipping kubeconfig in $HOME/.kube/config because HOME env variable is not set.")
			return nil
		}

		let kubeConfigURL = URL(fileURLWithPath: homePath + "/.kube/config")
		logger?.info("Loading configuration from \(kubeConfigURL)")

		return try from(url: kubeConfigURL)
	}

	static func fromServiceAccount(logger: Logger? = nil) throws -> KubeConfig? {
		guard
			let host = ProcessInfo.processInfo.environment["KUBERNETES_SERVICE_HOST"],
			let port = ProcessInfo.processInfo.environment["KUBERNETES_SERVICE_PORT"]
		else {
			logger?.warning("Skipping service account kubeconfig because either KUBERNETES_SERVICE_HOST or KUBERNETES_SERVICE_PORT is not set")
			return nil
		}

		let apiServerUrl = if host.contains(":") {
			"https://[\(host)]:\(port)"
		} else {
			"https://\(host):\(port)"
		}

		let tokenFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/token")
		guard let token = try? String(contentsOf: tokenFile, encoding: .utf8) else {
			logger?.warning("Did not find service account token at /var/run/secrets/kubernetes.io/serviceaccount/token")
			return nil
		}

		let namespaceFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/namespace")
		let namespace = try? String(contentsOf: namespaceFile, encoding: .utf8)
		if namespace == nil {
			logger?.debug("Did not find service account namespace at /var/run/secrets/kubernetes.io/serviceaccount/namespace")
		}

		let certificateAuthorityFile = URL(fileURLWithPath: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt")
		let certificateAuthorityData = try? Data(contentsOf: certificateAuthorityFile)

		return KubeConfig(
			kind: "Config",
			apiVersion: "v1",
			clusters: [
				NamedCluster(
					name: "kubernetes-cluster-local",
					cluster: Cluster(
						server: apiServerUrl,
						insecureSkipTLSVerify: certificateAuthorityData == nil,
						certificateAuthorityData: certificateAuthorityData
					)
				),
			],
			users: [
				NamedAuthInfo(
					name: "service-account-user",
					authInfo: AuthInfo(
						token: token
					)
				),
			],
			contexts: [
				NamedContext(
					name: "service-account-context",
					context: Context(
						cluster: "kubernetes-cluster-local",
						user: "service-account-user",
						namespace: namespace
					)
				),
			],
			currentContext: "service-account-context"
		)
	}
}

internal extension String {

	func stringByExpandingTildePath() -> String {
		guard !self.isEmpty else {
			return ""
		}

		if self == "~" {
			return FileManager.default.homeDirectoryForCurrentUser.path
		}

		guard self.hasPrefix("~/") else {
			return self
		}

		var relativePath = self
		relativePath.removeFirst(2)

		return FileManager.default.homeDirectoryForCurrentUser.path + "/" + relativePath
	}
}
