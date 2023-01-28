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
import NIO
import SwiftkubeModel

// MARK: - SwiftkubeClientTask

/// A Client task, which is created by the SwiftkubeClient in the context of ``GenericKubernetesClient/watch(in:options:retryStrategy:)``
/// or ``GenericKubernetesClient/follow(in:name:container:retryStrategy:)`` API requests.
///
/// The task instance must be started explicitly via ``SwiftkubeClientTask/start()``, which returns an
/// ``AsyncThrowingStream``, that starts yielding items immediately as they are received from the Kubernetes API server.
///
/// The async stream buffers its results if there are no active consumers. The ``AsyncThrowingStream.BufferingPolicy.unbounded``
/// buffering policy is used, which should be taken into consideration.
///
/// The task can be cancelled by calling its ``SwiftkubeClientTask/cancel()`` function.
///
/// The task is executed indefinitely. Upon encountering non-transient errors this tasks reconnects to the
/// Kubernetes API server, basically restarting the previous ``GenericKubernetesClient/watch(in:options:retryStrategy:)``
/// or ``GenericKubernetesClient/follow(in:name:container:retryStrategy:)`` call.
///
/// The retry semantics are controlled via the passed ``RetryStrategy`` instance by the Kubernetes client.
///
/// Example:
///
/// ```swift
/// let task = try client.configMaps.watch(in: .default)
/// let stream = task.start()
/// for try await item in stream {
///   print(item)
/// }
/// ```
public class SwiftkubeClientTask<Output> {

	private let client: HTTPClient
	private let request: KubernetesRequest
	private let streamer: DataStreamer<Output>
	private let logger: Logger
	private let retriesSequence: RetryStrategy.Iterator

	private var currentTask: Task<Void, Error>?
	private var cancelled: Bool = false

	internal init(
		client: HTTPClient,
		request: KubernetesRequest,
		streamer: DataStreamer<Output>,
		retryStrategy: RetryStrategy,
		logger: Logger
	) {
		self.client = client
		self.request = request
		self.streamer = streamer
		self.retriesSequence = retryStrategy.makeIterator()
		self.logger = logger
	}

	deinit {
		doCancel()
	}

	/// Starts this task, which then begins to immediately emit data as an asynchronous stream.
	///
	/// Starting a cancelled task has no effect. If this this task has been cancelled, then an empty stream is returned.
	///
	/// - Returns: An instance of ``AsyncThrowingStream`` emitting items as they received from the API server.
	public func start() -> AsyncThrowingStream<Output, Error> {
		if cancelled {
			return AsyncThrowingStream { nil }
		}

		logger.debug("Staring task for request: \(request)")
		return AsyncThrowingStream<Output, Error>(bufferingPolicy: .unbounded) { continuation in
			currentTask?.cancel()
			currentTask = makeTask(continuation: continuation)
		}
	}

	private func makeTask(continuation: AsyncThrowingStream<Output, Error>.Continuation) -> Task<Void, Error> {
		Task {
			while true {
				guard !Task.isCancelled else {
					logger.debug("Task for request: \(request) was cancelled")
					continuation.finish()
					break
				}

				do {
					let asyncRequest = try request.asAsyncClientRequest()
					let response = try await client.execute(asyncRequest, deadline: .distantFuture, logger: logger)
					let stream = streamer.doStream(response: response, logger: logger)

					for try await event in stream {
						continuation.yield(event)

						guard !Task.isCancelled else {
							logger.debug("Task for request: \(request) was cancelled")
							streamer.cancel()
							continuation.finish()
							break
						}
					}
				} catch {
					logger.debug("Error occurred while streaming data: \(error.localizedDescription)")
				}

				guard !Task.isCancelled else {
					logger.debug("Task for request: \(request) was cancelled")
					continuation.finish()
					break
				}

				guard let nextAttempt = retriesSequence.next() else {
					logger.debug("Max retries reached for request: \(request)")
					continuation.finish(throwing: SwiftkubeClientError.maxRetriesReached(request: request))
					break
				}

				let delaySeconds = nextAttempt.delay
				logger.debug("Will retry request: \(request) in \(delaySeconds) seconds")
				try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))

				guard !Task.isCancelled else {
					logger.debug("Task for request: \(request) was cancelled")
					continuation.finish()
					break
				}
			}
		}
	}

	/// Cancels the task execution.
	public func cancel() {
		doCancel()
	}

	private func doCancel() {
		cancelled = true
		currentTask?.cancel()
		currentTask = nil
	}
}
