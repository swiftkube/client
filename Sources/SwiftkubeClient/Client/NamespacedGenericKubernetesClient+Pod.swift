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
import NIO
import SwiftkubeModel

// MARK: - NamespacedGenericKubernetesClient

/// NamespacedGenericKubernetesClient extensions for ``core.v1.Pod`` resources.
public extension NamespacedGenericKubernetesClient where Resource == core.v1.Pod {

	/// Follows the logs of the specified container.
	///
	/// Following the logs of a container opens a persistent connection to the API server. The connection is represented
	/// by a ``SwiftkubeClientTask`` instance, that acts as an active "subscription" to the logs stream.
	///
	/// The task instance must be started explicitly via ``SwiftkubeClientTask/start()``, which returns an
	/// ``AsyncThrowingStream``, that begins yielding log lines immediately as they are received from the Kubernetes API server.
	///
	/// The async stream buffers its results if there are no active consumers. The ``AsyncThrowingStream.BufferingPolicy.unbounded``
	/// buffering policy is used, which should be taken into consideration.
	///
	/// The task can be cancelled by calling its ``SwiftkubeClientTask/cancel()`` function.
	///
	/// Example:
	///
	/// ```swift
	/// let task = try client.pods.follow(in: .namespace("default"), name: "nginx")
	/// let stream = task.start()
	/// for try await line in stream {
	///   print(line)
	///	}
	/// ```
	///
	/// Per default `follow` requests are not retried. To enable and control reconnect behaviour pass an instance
	/// of ``RetryStrategy``.
	///
	/// ```swift
	/// let strategy = RetryStrategy(
	///    policy: .maxAttempts(20),
	///    backoff: .exponentialBackoff(maxDelay: 60, multiplier: 2.0),
	///    initialDelay = 5.0,
	///    jitter = 0.2
	/// )
	/// let task = client.pods.follow(in: .default, name: "nginx", retryStrategy: strategy)
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the Pod.
	///   - container: The name of the container.
	///   - timestamps: Whether to include timestamps on the log lines.
	///   - retryStrategy: An instance of a ``RetryStrategy`` configuration to use.
	///
	/// - Returns: A ``SwiftkubeClientTask`` instance, representing a streaming connection to the API server.
	func follow(
		in namespace: NamespaceSelector? = nil,
		name: String,
		container: String? = nil,
		timestamps: Bool = false,
		retryStrategy: RetryStrategy = RetryStrategy.never
	) throws -> SwiftkubeClientTask<String> {
		try super.follow(
			in: namespace ?? .namespace(config.namespace),
			name: name,
			container: container,
			timestamps: timestamps,
			retryStrategy: retryStrategy
		)
	}

	/// Loads a container's logs once without streaming.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the pod.
	///   - container: The name of the container.
	///   - previous: Whether to request the logs of the previous instance of the container.
	///   - timestamps: Whether to include timestamps on the log lines.
	///
	/// - Returns: The container logs as a single String.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func logs(
		in namespace: NamespaceSelector? = nil,
		name: String,
		container: String? = nil,
		previous: Bool = false,
		timestamps: Bool = false
	) async throws -> String {
		try await super.logs(
			in: namespace ?? .namespace(config.namespace),
			name: name,
			container: container,
			previous: previous,
			timestamps: timestamps
		)
	}
}
