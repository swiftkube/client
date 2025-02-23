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

/// Kubernetes client class. Provides API for interaction with the Kubernetes master server.
///
/// This implementation is based on SwiftNIO and the AsyncHTTPClient.
///
/// Example:
///
/// ```swift
/// let client = try KubernetesClient()
/// let deployments = try await client.appsV1.deployments.list(in:.allNamespaces)
/// deployments.forEach { print($0) }
/// ```
public class KubernetesClient {

	/// The client's configuration object.
	public let config: KubernetesClientConfig
	internal let httpClient: HTTPClient
	internal let logger: Logger

	#if compiler(>=6.0)
		internal let jsonDecoder: JSONDecoder = {
			let timeFormatter = Date.ISO8601FormatStyle.iso8601
			let microTimeFormatter = Date.ISO8601FormatStyle.iso8601.time(includingFractionalSeconds: true)
			let jsonDecoder = JSONDecoder()
			jsonDecoder.dateDecodingStrategy = .custom { decoder -> Date in
				let string = try decoder.singleValueContainer().decode(String.self)

				if let date = try? timeFormatter.parse(string) {
					return date
				}

				if let date = try? microTimeFormatter.parse(string) {
					return date
				}

				let context = DecodingError.Context(
					codingPath: decoder.codingPath,
					debugDescription: "Expected date string to be either ISO8601 or ISO8601 with milliseconds."
				)
				throw DecodingError.dataCorrupted(context)
			}

			return jsonDecoder
		}()
	#else
		internal let jsonDecoder: JSONDecoder = {
			let timeFormatter: ISO8601DateFormatter = {
				let formatter = ISO8601DateFormatter()
				formatter.formatOptions = .withInternetDateTime
				return formatter
			}()

			let microTimeFormatter = {
				let formatter = ISO8601DateFormatter()
				formatter.formatOptions = .withFractionalSeconds
				return formatter
			}()
			let jsonDecoder = JSONDecoder()
			jsonDecoder.dateDecodingStrategy = .custom { decoder -> Date in
				let string = try decoder.singleValueContainer().decode(String.self)

				if let date = timeFormatter.date(from: string) {
					return date
				}

				if let date = microTimeFormatter.date(from: string) {
					return date
				}

				let context = DecodingError.Context(
					codingPath: decoder.codingPath,
					debugDescription: "Expected date string to be either ISO8601 or ISO8601 with milliseconds."
				)
				throw DecodingError.dataCorrupted(context)
			}

			return jsonDecoder
		}()
	#endif

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
	///    - provider: A ``EventLoopGroupProvider`` to specify how ``EventLoopGroup`` will be created.
	///    - logger: The logger to use for this client.
	public convenience init?(
		provider: HTTPClient.EventLoopGroupProvider = .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
		logger: Logger? = nil
	) {
		let logger = logger ?? SwiftkubeClient.loggingDisabled

		guard
			let config = KubernetesClientConfig.initialize(logger: logger)
		else {
			return nil
		}

		self.init(config: config, provider: provider, logger: logger)
	}

	/// Create a new instance of the Kubernetes client.
	///
	/// - Parameters:
	///    - url: The url to load the configuration from for this client instance. It can be a local file or remote URL.
	///    - provider: A ``EventLoopGroupProvider`` to specify how ``EventLoopGroup`` will be created.
	///    - logger: The logger to use for this client.
	public convenience init?(
		fromURL url: URL,
		provider: HTTPClient.EventLoopGroupProvider = .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
		logger: Logger? = nil
	) {
		let logger = logger ?? SwiftkubeClient.loggingDisabled

		guard
			let config = KubernetesClientConfig.create(fromUrl: url, logger: logger)
		else {
			return nil
		}

		self.init(config: config, provider: provider, logger: logger)
	}

	/// Create a new instance of the Kubernetes client.
	///
	/// - Parameters:
	///    - config: The configuration for this client instance.
	///    - provider: A ``EventLoopGroupProvider`` to specify how ``EventLoopGroup`` will be created.
	///    - logger: The logger to use for this client.
	public init(
		config: KubernetesClientConfig,
		provider: HTTPClient.EventLoopGroupProvider = .shared(MultiThreadedEventLoopGroup(numberOfThreads: 1)),
		logger: Logger? = nil
	) {
		self.config = config
		self.logger = logger ?? SwiftkubeClient.loggingDisabled

		var tlsConfiguration = TLSConfiguration.makeClientConfiguration()

		if config.insecureSkipTLSVerify {
			tlsConfiguration.certificateVerification = .none
		} else {
			tlsConfiguration.minimumTLSVersion = .tlsv12
			tlsConfiguration.trustRoots = config.trustRoots
		}

		if case let KubernetesClientAuthentication.x509(clientCertificate, clientKey) = config.authentication {
			tlsConfiguration.certificateChain = [.certificate(clientCertificate)]
			tlsConfiguration.privateKey = NIOSSLPrivateKeySource.privateKey(clientKey)
		}

		self.httpClient = HTTPClient(
			eventLoopGroupProvider: provider,
			configuration: HTTPClient.Configuration(
				tlsConfiguration: tlsConfiguration,
				redirectConfiguration: config.redirectConfiguration,
				timeout: config.timeout
			)
		)
	}

	/// Shuts down the client gracefully.
	///
	/// This function uses a completion instead of an EventLoopFuture, because the underlying event loop will be closed
	/// by the time a EventLoopFuture calls back. Instead the callback is executed on a ``DispatchQueue``.
	///
	/// - Parameters:
	///   - queue: The ``DispatchQueue`` for the callback upon completion.
	///   - callback: The callback indicating any errors encountered during shutdown.
	public func shutdown(queue: DispatchQueue, _ callback: @Sendable @escaping (Error?) -> Void) {
		httpClient.shutdown(queue: queue, callback)
	}

	/// Shuts down the client asynchronously.
	public func shutdown() async throws {
		try await httpClient.shutdown()
	}

	/// Shuts down the client synchronously.
	public func syncShutdown() throws {
		try httpClient.syncShutdown()
	}
}

/// Convenience functions to construct a client instance scoped at cluster or namespace level.
public extension KubernetesClient {

	/// Create a new generic client for the given ``KubernetesAPIResource``.
	///
	/// This assumes a known Kubernetes resource type, i.e. it constructs a ``GroupVersionResource`` for its
	/// internal use from the `R.Type`. For unknown resource types, e.g. CRDs, you can use
	/// ``KubernetesClient/for(_:gvr:)`` instead.
	///
	/// - Parameter type: The `KubernetesAPIResource` type.
	/// - Returns A new `GenericKubernetesClient` for the given resource's `KubernetesAPIResource`.
	func `for`<R: KubernetesAPIResource>(_ type: R.Type) -> GenericKubernetesClient<R> {
		GenericKubernetesClient<R>(httpClient: httpClient, config: config, jsonDecoder: jsonDecoder, logger: logger)
	}

	/// Create a new unstructured client for the given ``GroupVersionResource``.
	///
	/// The returned resource is unstructured, i.e. of the ``UnstructuredResource`` type.
	///
	/// - Parameter gvr: The ``GroupVersionResource`` of the desired resource.
	/// - Returns A new ``GenericKubernetesClient`` for the given resource's ``GroupVersionResource``. This client decodes
	/// kubernetes objects as ``UnstructuredResource``s.
	func `for`(gvr: GroupVersionResource) -> GenericKubernetesClient<UnstructuredResource> {
		GenericKubernetesClient<UnstructuredResource>(httpClient: httpClient, config: config, gvr: gvr, jsonDecoder: jsonDecoder, logger: logger)
	}

	/// Create a new generic client for the given a ``KubernetesAPIResource`` type and its ``GroupVersionResource``.
	///
	/// The returned instance is typed-inferred by the generic constraint.
	///
	/// - Parameters:
	///   - type: The ``KubernetesAPIResource`` type.
	///   - gvr: The ``GroupVersionResource`` of the desired resource.
	/// - Returns A new `GenericKubernetesClient` for the given resource's `GroupVersionResource`.
	func `for`<R: KubernetesAPIResource>(_ type: R.Type, gvr: GroupVersionResource) -> GenericKubernetesClient<R> {
		GenericKubernetesClient<R>(httpClient: httpClient, config: config, gvr: gvr, jsonDecoder: jsonDecoder, logger: logger)
	}

	/// Create a new `cluster-scoped` client for the given cluster-scoped resoruce type.
	///
	/// - Parameter type: The `KubernetesAPIResource` type.
	/// - Returns A new ``ClusterScopedGenericKubernetesClient`` for the given resource type.
	func clusterScoped<R: KubernetesAPIResource & ClusterScopedResource>(for type: R.Type) -> ClusterScopedGenericKubernetesClient<R> {
		ClusterScopedGenericKubernetesClient<R>(httpClient: httpClient, config: config, jsonDecoder: jsonDecoder, logger: logger)
	}

	/// Create a new `namespace-scoped` client for the given namespace-scoped resoruce type.
	///
	/// - Parameter type: The ``KubernetesAPIResource`` type.
	/// - Returns A new ``NamespacedGenericKubernetesClient`` for the given resource type.
	func namespaceScoped<R: KubernetesAPIResource & NamespacedResource>(for type: R.Type) -> NamespacedGenericKubernetesClient<R> {
		NamespacedGenericKubernetesClient<R>(httpClient: httpClient, config: config, jsonDecoder: jsonDecoder, logger: logger)
	}
}

/// Scoped client DSL for the `core` API Group
public extension KubernetesClient {

	/// Constructs a namespace-scoped client for ``core.v1.Binding`` resources.
	var bindings: NamespacedGenericKubernetesClient<core.v1.Binding> {
		namespaceScoped(for: core.v1.Binding.self)
	}

	/// Constructs a cluster-scoped client for ``core.v1.ComponentStatus`` resources.
	var componentStatuses: ClusterScopedGenericKubernetesClient<core.v1.ComponentStatus> {
		clusterScoped(for: core.v1.ComponentStatus.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.ConfigMap`` resources.
	var configMaps: NamespacedGenericKubernetesClient<core.v1.ConfigMap> {
		namespaceScoped(for: core.v1.ConfigMap.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.Endpoints`` resources.
	var endpoints: NamespacedGenericKubernetesClient<core.v1.Endpoints> {
		namespaceScoped(for: core.v1.Endpoints.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.Event`` resources.
	var events: NamespacedGenericKubernetesClient<core.v1.Event> {
		namespaceScoped(for: core.v1.Event.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.LimitRange`` resources.
	var limitRanges: NamespacedGenericKubernetesClient<core.v1.LimitRange> {
		namespaceScoped(for: core.v1.LimitRange.self)
	}

	/// Constructs a cluster-scoped client for ``core.v1.Namespace`` resources.
	var namespaces: ClusterScopedGenericKubernetesClient<core.v1.Namespace> {
		clusterScoped(for: core.v1.Namespace.self)
	}

	/// Constructs a cluster-scoped client for ``core.v1.Node`` resources.
	var nodes: ClusterScopedGenericKubernetesClient<core.v1.Node> {
		clusterScoped(for: core.v1.Node.self)
	}

	/// Constructs a cluster-scoped client for ``core.v1.PersistentVolume`` resources.
	var persistentVolumes: ClusterScopedGenericKubernetesClient<core.v1.PersistentVolume> {
		clusterScoped(for: core.v1.PersistentVolume.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.PersistentVolumeClaim`` resources.
	var persistentVolumeClaims: NamespacedGenericKubernetesClient<core.v1.PersistentVolumeClaim> {
		namespaceScoped(for: core.v1.PersistentVolumeClaim.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.Pod`` resources.
	var pods: NamespacedGenericKubernetesClient<core.v1.Pod> {
		namespaceScoped(for: core.v1.Pod.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.PodTemplate`` resources.
	var podTemplates: NamespacedGenericKubernetesClient<core.v1.PodTemplate> {
		namespaceScoped(for: core.v1.PodTemplate.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.ReplicationController`` resources.
	var replicationControllers: NamespacedGenericKubernetesClient<core.v1.ReplicationController> {
		namespaceScoped(for: core.v1.ReplicationController.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.ResourceQuota`` resources.
	var resourceQuotas: NamespacedGenericKubernetesClient<core.v1.ResourceQuota> {
		namespaceScoped(for: core.v1.ResourceQuota.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.Secret`` resources.
	var secrets: NamespacedGenericKubernetesClient<core.v1.Secret> {
		namespaceScoped(for: core.v1.Secret.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.Service`` resources.
	var services: NamespacedGenericKubernetesClient<core.v1.Service> {
		namespaceScoped(for: core.v1.Service.self)
	}

	/// Constructs a namespace-scoped client for ``core.v1.ServiceAccount`` resources.
	var serviceAccounts: NamespacedGenericKubernetesClient<core.v1.ServiceAccount> {
		namespaceScoped(for: core.v1.ServiceAccount.self)
	}
}
