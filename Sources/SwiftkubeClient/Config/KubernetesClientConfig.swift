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
import NIOCore
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

// MARK: - CachedFileTokenSource

/// A thread-safe, file-backed token source that caches the token with a synthetic TTL.
///
/// The token file is re-read from disk only when the cached value has expired.
/// This mirrors the caching strategy used by client-go's `fileTokenSource` /
/// `cachingTokenSource`, which stamps each read with a synthetic 1-minute expiry
/// so the file is re-read roughly every minute rather than on every request.
public final class CachedFileTokenSource: @unchecked Sendable {

	/// The path to the token file on disk.
	public var path: String {
		lock.withLock { state.path }
	}

	private struct State {
		var path: String
		var cachedToken: String?
		var expiry: NIODeadline = .distantPast
		var cacheDuration: TimeAmount
	}

	private let lock = NSLock()
	private var state: State

	/// Creates a new cached file token source.
	/// - Parameters:
	///   - path: The filesystem path to the token file.
	///   - cacheDuration: How long to cache a token before re-reading from disk. Defaults to 60 seconds.
	public init(path: String, cacheDuration: TimeAmount = .seconds(60)) {
		self.state = State(path: path, cacheDuration: cacheDuration)
	}

	/// Returns the current token, re-reading from disk if the cache has expired.
	public func token() -> String? {
		lock.withLock {
			let now = NIODeadline.now()
			if let cachedToken = state.cachedToken, now < state.expiry {
				return cachedToken
			}

			guard let newToken = try? String(contentsOfFile: state.path, encoding: .utf8) else {
				return nil
			}

			let trimmed = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
			state.cachedToken = trimmed
			state.expiry = now + state.cacheDuration
			return trimmed
		}
	}
}

// MARK: - KubernetesClientAuthentication

/// Supported client authentication schemes.
public enum KubernetesClientAuthentication: Sendable {
	/// Basic Authentincation via username/password.
	case basicAuth(username: String, password: String)
	/// Bearer token authentication scheme via a valid API token.
	case bearer(token: String)
	/// File-backed bearer token with a cached token source that re-reads from disk periodically.
	case tokenFile(source: CachedFileTokenSource)
	/// Certificate-based authenticaiton scheme with valid client certificate-key pair.
	case x509(clientCertificate: NIOSSLCertificate, clientKey: NIOSSLPrivateKey)

	internal func authorizationHeader() -> String? {
		switch self {
		case let .basicAuth(username: username, password: password):
			return HTTPClient.Authorization.basic(username: username, password: password).headerValue
		case let .bearer(token: token):
			return HTTPClient.Authorization.bearer(tokens: token).headerValue
		case let .tokenFile(source: source):
			guard let token = source.token() else {
				return nil
			}
			return HTTPClient.Authorization.bearer(tokens: token).headerValue
		default:
			return nil
		}
	}
}
