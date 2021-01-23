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
import Metrics
import NIO
import NIOHTTP1
import NIOSSL
import SwiftkubeModel

// MARK: - KubernetesClient

/// Kubernetes client class. Provies API for interaction with the Kubernetes master server.
///
/// This implementation is based on SwiftNIO and the AysncHTTPClient, i.e. API calls return `EventLoopFuture`s.
///
/// Example:
///
/// ```swift
/// let client = try KubernetesClient()
/// let deployments = try client.appsV1.deployments.list(in:.allNamespaces).wait()
/// deployments.forEach { print($0) }
/// ```
public class KubernetesClient {

	internal static let loggingDisabled = Logger(label: "SKC-do-not-log", factory: { _ in SwiftLogNoOpLogHandler() })

	/// The client's configuration object.
	public let config: KubernetesClientConfig
	private let httpClient: HTTPClient
	private let logger: Logger

	/// Create a new instance of the Kubernetes client.
	///
	/// The client tries to resolve a `kube config` automatically from different sources in the following order:
	///
	/// - A Kube config file in the user's `$HOME/.kube/config` directory
	/// - `ServiceAccount` token located at `/var/run/secrets/kubernetes.io/serviceaccount/token` and a mounted CA certificate, if it's running in Kubernetes.
	///
	/// Returns `nil` if a configuration can't be found.
	///
	/// - Parameters:
	///    - provider: Specify how `EventLoopGroup` will be created.
	///    - logger: The logger to use for this client.
	public convenience init?(
		provider: HTTPClient.EventLoopGroupProvider = .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
		logger: Logger? = nil
	) {
		let logger = logger ?? KubernetesClient.loggingDisabled

		guard
			let config =
			(try? LocalFileConfigLoader().load(logger: logger)) ??
			(try? ServiceAccountConfigLoader().load(logger: logger))
		else {
			return nil
		}

		self.init(config: config, provider: provider, logger: logger)
	}

	/// Create a new instance of the Kubernetes client.
	///
	/// - Parameters:
	///    - config: The configuration for this client instance.
	///    - provider: Specify how `EventLoopGroup` will be created.
	///    - logger: The logger to use for this client.
	public init(
		config: KubernetesClientConfig,
		provider: HTTPClient.EventLoopGroupProvider = .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
		logger: Logger? = nil
	) {
		self.config = config
		self.logger = logger ?? KubernetesClient.loggingDisabled

		var tlsConfiguration = TLSConfiguration.forClient(
			minimumTLSVersion: .tlsv12,
			certificateVerification: .fullVerification
		)

		tlsConfiguration.trustRoots = self.config.trustRoots

		if case let KubernetesClientAuthentication.x509(clientCertificate, clientKey) = self.config.authentication {
			tlsConfiguration.certificateChain = [.certificate(clientCertificate)]
			tlsConfiguration.privateKey = NIOSSLPrivateKeySource.privateKey(clientKey)
		}

		self.httpClient = HTTPClient(
			eventLoopGroupProvider: provider,
			configuration: HTTPClient.Configuration(
				tlsConfiguration: tlsConfiguration,
				redirectConfiguration: .follow(max: 10, allowCycles: false),
				timeout: .init(connect: .seconds(1))
			)
		)
	}

	public func syncShutdown() throws {
		try httpClient.syncShutdown()
	}
}

/// Convenience functions to construct a client instance scoped at cluster or namespace level.
public extension KubernetesClient {

	/// Create a new generic client for the given `KubernetesAPIResource`.
	///
	/// - Parameter gvk: The `KubernetesAPIResource` type.
	/// - Returns A new `GenericKubernetesClient` for the given resource's `KubernetesAPIResource`.
	func `for`<R: KubernetesAPIResource>(_ type: R.Type) -> GenericKubernetesClient<R> {
		GenericKubernetesClient<R>(httpClient: httpClient, config: config, logger: logger)
	}

	/// Create a new generic client for the given `GroupVersionKind`.
	///
	/// The returned instance is type-erased, i.e. returns the wrapper type `AnyKubernetesAPIResource`.
	///
	/// - Parameter gvk: The `GroupVersionKind` of the desired resource.
	/// - Returns A new `GenericKubernetesClient` for the given resource's `GenericKubernetesClient`.
	func `for`(gvk: GroupVersionKind) -> GenericKubernetesClient<AnyKubernetesAPIResource> {
		GenericKubernetesClient<AnyKubernetesAPIResource>(httpClient: httpClient, config: config, gvk: gvk, logger: logger)
	}

	/// Create a new `cluster-scoped` client for the given cluster-scoped resoruce type.
	///
	/// - Parameter type: The `KubernetesAPIResource` type.
	/// - Returns A new `ClusterScopedGenericKubernetesClient` for the given resource type.
	func clusterScoped<R: KubernetesAPIResource & ClusterScopedResource>(for type: R.Type) -> ClusterScopedGenericKubernetesClient<R> {
		ClusterScopedGenericKubernetesClient<R>(httpClient: httpClient, config: config, logger: logger)
	}

	/// Create a new `namespace-scoped` client for the given namespace-scoped resoruce type.
	///
	/// - Parameter type: The `KubernetesAPIResource` type.
	/// - Returns A new `NamespacedGenericKubernetesClient` for the given resource type.
	func namespaceScoped<R: KubernetesAPIResource & NamespacedResource>(for type: R.Type) -> NamespacedGenericKubernetesClient<R> {
		NamespacedGenericKubernetesClient<R>(httpClient: httpClient, config: config, logger: logger)
	}
}

/// Scoped client DSL for the `core` API Group
public extension KubernetesClient {

	/// Constructs a namespace-scoped client for `core.v1.ConfigMap` resources.
	var configMaps: NamespacedGenericKubernetesClient<core.v1.ConfigMap> {
		namespaceScoped(for: core.v1.ConfigMap.self)
	}

	/// Constructs a namespace-scoped client for `core.v1.Event` resources.
	var events: NamespacedGenericKubernetesClient<core.v1.Event> {
		namespaceScoped(for: core.v1.Event.self)
	}

	/// Constructs a cluster-scoped client for `core.v1.Namespace` resources.
	var namespaces: ClusterScopedGenericKubernetesClient<core.v1.Namespace> {
		clusterScoped(for: core.v1.Namespace.self)
	}

	/// Constructs a cluster-scoped client for `core.v1.Node` resources.
	var nodes: ClusterScopedGenericKubernetesClient<core.v1.Node> {
		clusterScoped(for: core.v1.Node.self)
	}

	/// Constructs a namespace-scoped client for `core.v1.Pod` resources.
	var pods: NamespacedGenericKubernetesClient<core.v1.Pod> {
		namespaceScoped(for: core.v1.Pod.self)
	}

	/// Constructs a namespace-scoped client for `core.v1.Secret` resources.
	var secrets: NamespacedGenericKubernetesClient<core.v1.Secret> {
		namespaceScoped(for: core.v1.Secret.self)
	}

	/// Constructs a namespace-scoped client for `core.v1.Service` resources.
	var services: NamespacedGenericKubernetesClient<core.v1.Service> {
		namespaceScoped(for: core.v1.Service.self)
	}
}
