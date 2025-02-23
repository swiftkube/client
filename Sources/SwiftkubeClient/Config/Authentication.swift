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
import NIOSSL

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
