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
import NIOSSL
import Yams

// MARK: - KubeConfig

/// Represents a kube-config struct, i.e. `$HOME/.kube/config`
///
/// Where possible, json tags match the cli argument names.
/// Top level config objects and all values required for proper functioning are not "omitempty".  Any truly optional piece of config is allowed to be omitted.
/// Config holds the information needed to build connect to remote kubernetes clusters as a given user
public struct KubeConfig: Codable, Sendable {

	enum CodingKeys: String, CodingKey {
		case kind, apiVersion, clusters, users, contexts
		case currentContext = "current-context"
	}

	/// Legacy field from pkg/api/types.go TypeMeta.
	public var kind: String?

	/// Legacy field from pkg/api/types.go TypeMeta.
	public var apiVersion: String?

	/// Clusters is a map of referencable names to cluster configs
	public var clusters: [NamedCluster]?

	/// AuthInfos is a map of referencable names to user configs
	public var users: [NamedAuthInfo]?

	/// Contexts is a map of referencable names to context configs
	public var contexts: [NamedContext]?

	/// CurrentContext is the name of the context that you would like to use by default
	public var currentContext: String?
}

// MARK: - Cluster

/// Cluster contains information about how to communicate with a kubernetes cluster.
public struct Cluster: Codable, Sendable, Hashable, Equatable {

	public init(
		server: String,
		tlsServerName: String? = nil,
		insecureSkipTLSVerify: Bool? = nil,
		certificateAuthority: String? = nil,
		certificateAuthorityData: Data? = nil,
		proxyURL: String? = nil
	) {
		self.server = server
		self.tlsServerName = tlsServerName
		self.insecureSkipTLSVerify = insecureSkipTLSVerify
		self.certificateAuthority = certificateAuthority
		self.certificateAuthorityData = certificateAuthorityData
		self.proxyURL = proxyURL
	}

	enum CodingKeys: String, CodingKey {
		case server
		case tlsServerName = "tls-server-name"
		case insecureSkipTLSVerify = "insecure-skip-tls-verify"
		case certificateAuthority = "certificate-authority"
		case certificateAuthorityData = "certificate-authority-data"
		case proxyURL = "proxy-url"
	}

	/// Server is the address of the kubernetes cluster (https://hostname:port).
	public var server: String

	/// TLSServerName is used to check server certificate. If TLSServerName is empty, the hostname used to contact the server is used.
	public var tlsServerName: String?

	/// InsecureSkipTLSVerify skips the validity check for the server's certificate. This will make your HTTPS connections insecure.
	public var insecureSkipTLSVerify: Bool?

	/// CertificateAuthority is the path to a cert file for the certificate authority.
	public var certificateAuthority: String?

	/// CertificateAuthorityData contains PEM-encoded certificate authority certificates. Overrides CertificateAuthority.
	public var certificateAuthorityData: Data?

	/// ProxyURL is the URL to the proxy to be used for all requests made by this client.
	public var proxyURL: String?
}

// MARK: - AuthInfo

/// AuthInfo contains information that describes identity information.  This is use to tell the kubernetes cluster who you are.
public struct AuthInfo: Codable, Sendable, Hashable, Equatable {

	public init(
		clientCertificate: String? = nil,
		clientCertificateData: Data? = nil,
		clientKey: String? = nil,
		clientKeyData: Data? = nil,
		token: String? = nil,
		tokenFile: String? = nil,
		impersonate: String? = nil,
		impersonateGroups: [String]? = nil,
		impersonateUserExtra: [String: String]? = nil,
		username: String? = nil,
		password: String? = nil,
		authProvider: AuthProviderConfig? = nil,
		exec: ExecConfig? = nil
	) {
		self.clientCertificate = clientCertificate
		self.clientCertificateData = clientCertificateData
		self.clientKey = clientKey
		self.clientKeyData = clientKeyData
		self.token = token
		self.tokenFile = tokenFile
		self.impersonate = impersonate
		self.impersonateGroups = impersonateGroups
		self.impersonateUserExtra = impersonateUserExtra
		self.username = username
		self.password = password
		self.authProvider = authProvider
		self.exec = exec
	}

	enum CodingKeys: String, CodingKey {
		case clientCertificate = "client-certificate"
		case clientCertificateData = "client-certificate-data"
		case clientKey = "client-key"
		case clientKeyData = "client-key-data"
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

	/// ClientCertificate is the path to a client cert file for TLS.
	public var clientCertificate: String?

	/// ClientCertificateData contains PEM-encoded data from a client cert file for TLS. Overrides ClientCertificate.
	public var clientCertificateData: Data?

	/// ClientKey is the path to a client key file for TLS.
	public var clientKey: String?

	/// ClientKeyData contains PEM-encoded data from a client key file for TLS. Overrides ClientKey.
	public var clientKeyData: Data?

	/// Token is the bearer token for authentication to the kubernetes cluster.
	public var token: String?

	/// TokenFile is a pointer to a file that contains a bearer token (as described above).  If both Token and TokenFile are present, Token takes precedence.
	public var tokenFile: String?

	/// Impersonate is the username to imperonate.  The name matches the flag.
	public var impersonate: String?

	/// ImpersonateGroups is the groups to imperonate.
	public var impersonateGroups: [String]?

	/// ImpersonateUserExtra contains additional information for impersonated user.
	public var impersonateUserExtra: [String: String]?

	/// Username is the username for basic authentication to the kubernetes cluster.
	public var username: String?

	/// Password is the password for basic authentication to the kubernetes cluster.
	public var password: String?

	/// AuthProvider specifies a custom authentication plugin for the kubernetes cluster.
	public var authProvider: AuthProviderConfig?

	/// Exec specifies a custom exec-based authentication plugin for the kubernetes cluster.
	public var exec: ExecConfig?
}

// MARK: - Context

/// Context is a tuple of references to a cluster (how do I communicate with a kubernetes cluster), a user (how do I identify myself), and a namespace (what subset of resources do I want to work with)
public struct Context: Codable, Sendable {

	/// Cluster is the name of the cluster for this context.
	public var cluster: String

	/// AuthInfo is the name of the authInfo for this context.
	public var user: String

	/// Namespace is the default namespace to use on unspecified requests.
	public var namespace: String?
}

// MARK: - NamedCluster

/// NamedCluster relates nicknames to cluster information.
public struct NamedCluster: Codable, Sendable {

	/// Name is the nickname for this Cluster.
	public var name: String

	/// Cluster holds the cluster information.
	public var cluster: Cluster
}

// MARK: - NamedContext

/// NamedContext relates nicknames to context information.
public struct NamedContext: Codable, Sendable {

	/// Name is the nickname for this Context.
	public var name: String

	/// Context holds the context information.
	public var context: Context
}

// MARK: - NamedAuthInfo

/// NamedAuthInfo relates nicknames to auth information.
public struct NamedAuthInfo: Codable, Sendable {
	enum CodingKeys: String, CodingKey {
		case name
		case authInfo = "user"
	}

	/// Name is the nickname for this AuthInfo
	public var name: String

	/// AuthInfo holds the auth information.
	public var authInfo: AuthInfo
}

// MARK: - AuthProviderConfig

/// AuthProviderConfig holds the configuration for a specified auth provider.
public struct AuthProviderConfig: Codable, Sendable, Hashable, Equatable {

	/// Name is the nickname for this AuthProviderConfig.
	public var name: String

	/// Holds the config for this AuthProvider.
	public var config: [String: String]
}

// MARK: - ExecConfig

///  ExecConfig specifies a command to provide client credentials.
///  The command is exec'd and outputs structured stdout holding credentials.
///  See the client.authentication.k8s.io API group for specifications of the exact input and output format
public struct ExecConfig: Codable, Sendable, Hashable, Equatable {
	/// Command to execute.
	public var command: String

	/// Arguments to pass to the command when executing it.
	public var args: [String]?

	/// Env defines additional environment variables to expose to the process.
	/// These are unioned with the host's environment, as well as variables client-go uses  to pass argument to the plugin.
	public var env: [ExecEnvVar]?

	/// Preferred input version of the ExecInfo. The returned ExecCredentials MUST use the same encoding version as the input.
	public var apiVersion: String

	/// This text is shown to the user when the executable doesn't seem to be
	/// present. For example, `brew install foo-cli` might be a good InstallHint for
	/// foo-cli on Mac OS systems.
	public var installHint: String?

	/// ProvideClusterInfo determines whether or not to provide cluster information,
	/// which could potentially contain very large CA data, to this exec plugin as a
	/// part of the KUBERNETES_EXEC_INFO environment variable. By default, it is set
	/// to false. Package k8s.io/client-go/tools/auth/exec provides helper methods for
	/// reading this environment variable.
	public var provideClusterInfo: Bool?

	/// InteractiveMode determines this plugin's relationship with standard input. Valid
	/// values are "Never" (this exec plugin never uses standard input), "IfAvailable" (this
	/// exec plugin wants to use standard input if it is available), or "Always" (this exec
	/// plugin requires standard input to function). See ExecInteractiveMode values for more
	/// details.
	///
	/// If APIVersion is client.authentication.k8s.io/v1alpha1 or
	/// client.authentication.k8s.io/v1beta1, then this field is optional and defaults
	/// to "IfAvailable" when unset. Otherwise, this field is required.
	public var interactiveMode: String?
}

// MARK: - ExecEnvVar

/// ExecEnvVar is used for setting environment variables when executing an exec-based credential plugin.
public struct ExecEnvVar: Codable, Sendable, Hashable, Equatable {

	/// Variable name.
	public var name: String

	/// Varbiale value.
	public var value: String
}
