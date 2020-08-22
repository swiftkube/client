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

public struct KubeConfig: Codable {

	enum CodingKeys: String, CodingKey {
		case kind, apiVersion, clusters, users, contexts
		case currentContext = "current-context"
	}

	public var kind: String?

	public var apiVersion: String?

	public var clusters: [NamedCluster]?

	public var users: [NamedAuthInfo]?

	public var contexts: [NamedContext]?

	public var currentContext: String?

}

public struct Cluster: Codable {

	enum CodingKeys: String, CodingKey {
		case server
		case tlsServerName = "tls-server-name"
		case insecureSkipTLSVerify = "insecure-skip-tls-verify"
		case certificateAuthority = "certificate-authority"
		case certificateAuthorityData = "certificate-authority-data"
		case proxyURL = "proxy-url"
	}

	public var server: String

	public var tlsServerName: String?

	public var insecureSkipTLSVerify: Bool?

	public var certificateAuthority: String?

	public var certificateAuthorityData: Data?

	public var proxyURL: String?

}

public struct AuthInfo: Codable {

	enum CodingKeys: String, CodingKey {
		case clientCertificate = "client-certificate"
		case clientCertificateData = "client-certificate-data"
		case clientKey = "client-key"
		case clientKeyData = "certificate-key-data"
		case token
		case tokenFile = "token-file"
		case impersonate
		case impersonateGroups = "impersonate-groups"
		case impersonateUserExtra = "impersonate-user-extra"
		case username
		case password
		case authProvider = "auth-provider"
		case exec
	}

	public var clientCertificate: String?

	public var clientCertificateData: Data?

	public var clientKey: String?

	public var clientKeyData: Data?

	public var token: String?

	public var tokenFile: String?

	public var impersonate: String?

	public var impersonateGroups: [String]?

	public var impersonateUserExtra: [String: String]?

	public var username: String?

	public var password: String?

	public var authProvider: AuthProviderConfig?

	public var exec: ExecConfig?
}

public struct Context: Codable {

	public var cluster: String

	public var user: String

	public var namespace: String?
}

public struct NamedCluster: Codable {

	public var name: String

	public var cluster: Cluster
}

public struct NamedContext: Codable {

	public var name: String

	public var context: Context
}

public struct NamedAuthInfo: Codable {

	enum CodingKeys: String, CodingKey {
		case name
		case authInfo = "user"
	}

	public var name: String

	public var authInfo: AuthInfo
}

public struct AuthProviderConfig: Codable {

	public var name: String

	public var config: [String: String]
}

public struct ExecConfig: Codable {

	public var command: String

	public var args: [String]?

	public var env: [ExecEnvVar]?

	public var apiVersion: String
}

public struct ExecEnvVar: Codable {

	public var name: String

	public var value: String
}
