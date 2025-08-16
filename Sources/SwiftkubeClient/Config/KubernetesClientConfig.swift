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

// MARK: - KubernetesClientAuthentication

/// Supported client authentication schemes.
public enum KubernetesClientAuthentication: Sendable {
	/// Basic Authentincation via username/password.
	case basicAuth(username: String, password: String)
	/// Bearer token authentication scheme via a valid API token.
	case bearer(token: String)
	/// Certificate-based authenticaiton scheme with valid client certificate-key pair.
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
