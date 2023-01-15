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
	/// Following the logs of a container opens a persistent connection to the API server. The connection is represented by a ``SwiftkubeClientTask`` instance, that acts
	/// as an active "subscription" to the logs stream. The task can be cancelled any time to stop the watch.
	///
	/// If the namespace is not specified then the default namespace defined in the ``KubernetesClientConfig`` will be used instead.
	///
	/// ```swift
	/// let task: HTTPClient.Task<Void> = client.pods.follow(in: .namespace("default"), name: "nginx") { line in
	///    print(line)
	///	}
	///
	///	task.cancel()
	/// ```
	///
	/// The reconnect behaviour can be controlled by passing an instance of ``RetryStrategy``. Per default `follow` requests are not retried.
	///
	/// ```swift
	/// let strategy = RetryStrategy(
	///    policy: .maxAttempts(20),
	///    backoff: .exponentialBackoff(maxDelay: 60, multiplier: 2.0),
	///    initialDelay = 5.0,
	///    jitter = 0.2
	/// )
	/// let task = client.pods.follow(in: .default, name: "nginx", retryStrategy: strategy) { line in print(line) }
	/// ```
	///
	/// - Parameters:
	///   - namespace: The namespace for this API request.
	///   - name: The name of the Pod.
	///   - container: The name of the container.
	///   - retryStrategy: An instance of a ``RetryStrategy`` configuration to use.
	///   - lineHandler: A ``LogWatcherCallback.LineHandler`` instance, which is used as a callback for new log lines.
	///
	/// - Returns: A cancellable ``SwiftkubeClientTask`` instance, representing a streaming connection to the API server.
	func follow(
		in namespace: NamespaceSelector? = nil,
		name: String,
		container: String? = nil,
		retryStrategy: RetryStrategy = RetryStrategy.never,
		lineHandler: @escaping LogWatcherCallback.LineHandler
	) throws -> SwiftkubeClientTask {
		let delegate = LogWatcherCallback(onError: nil, onNext: lineHandler)
		return try super.follow(
			in: namespace ?? .namespace(config.namespace),
			name: name,
			container: container,
			retryStrategy: retryStrategy,
			delegate: delegate
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
	///
	/// - Returns: The container logs as a single String.
	/// - Throws: An error of type ``SwiftkubeClientError``.
	func logs(
		in namespace: NamespaceSelector? = nil,
		name: String,
		container: String? = nil
	) async throws -> String {
		try await super.logs(
			in: namespace ?? .namespace(config.namespace),
			name: name,
			container: container
		)
	}
}
