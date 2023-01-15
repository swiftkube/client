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

// MARK: - SwiftkubeClientTaskDelegate

/// An internal delegate type for passing ``HTTPClientResponseDelegate``'s lifecycle events to the ``SwiftkubeClientTask`` instance.
internal protocol SwiftkubeClientTaskDelegate {
	func onError(error: SwiftkubeClientError)
	func onDidFinish(task: HTTPClient.Task<Void>)
}

// MARK: - SwiftkubeClientTask

/// A Client task, which is created by the SwiftkubeClient in the context of ``GenericKubernetesClient/watch(in:options:retryStrategy:using:)``
/// or ``GenericKubernetesClient/follow(in:name:container:retryStrategy:delegate:)`` API requests.
///
/// The task can be used to cancel the task execution.
///
/// The task is executed indefinitely. Upon encountering non-transient errors this tasks reconnects to the
/// Kubernetes API server, basically restarting the previous ``GenericKubernetesClient/watch(in:options:retryStrategy:using:)``
/// or ``GenericKubernetesClient/follow(in:name:container:retryStrategy:delegate:)`` call.
///
/// The retry semantics are controlled via the passed ``RetryStrategy`` instance by the Kubernetes client.
public class SwiftkubeClientTask: SwiftkubeClientTaskDelegate {

	let client: HTTPClient
	let request: KubernetesRequest
	let streamingDelegate: ClientStreamingDelegate
	let promise: EventLoopPromise<Void>
	let retriesSequence: RetryStrategy.Iterator
	let logger: Logger
	var cancelled = false
	var clientTask: HTTPClient.Task<Void>?

	init(
		client: HTTPClient,
		request: KubernetesRequest,
		streamingDelegate: ClientStreamingDelegate,
		logger: Logger,
		retryStrategy: RetryStrategy = RetryStrategy()
	) {
		self.client = client
		self.request = request
		self.streamingDelegate = streamingDelegate
		self.promise = client.eventLoopGroup.next().makePromise()
		self.retriesSequence = retryStrategy.makeIterator()
		self.logger = logger
		self.streamingDelegate.taskDelegate = self
	}

	internal func schedule(in amount: TimeAmount) {
		guard clientTask == nil else {
			return
		}

		logger.debug("Scheduling task for request: \(request)")
		let scheduled = client.eventLoopGroup.next().scheduleTask(in: amount) { () -> HTTPClient.Task<Void> in
			try self.resetAndExecute()
		}

		scheduled.futureResult.whenComplete { (result: Result<HTTPClient.Task<Void>, Error>) in
			switch result {
			case let .success(task):
				self.clientTask = task
			case let .failure(error):
				self.promise.fail(SwiftkubeClientError.taskError(error))
			}
		}
	}

	private func resetAndExecute() throws -> HTTPClient.Task<Void> {
		streamingDelegate.reset()
		do {
			let syncClientRequest = try request.asClientRequest()
			return client.execute(request: syncClientRequest, delegate: streamingDelegate, logger: logger)
		} catch {
			promise.fail(error)
			throw error
		}
	}

	internal func onDidFinish(task: HTTPClient.Task<Void>) {
		logger.debug("Task finished for request: \(request)")
		reconnect()
	}

	internal func onError(error: SwiftkubeClientError) {
		logger.debug("Error received: \(error) for request: \(request)")
		reconnect()
	}

	private func reconnect() {
		guard !cancelled else {
			logger.debug("Task was cancelled for request: \(request)")
			return
		}

		logger.debug("Reconnecting task for request: \(request)")
		stopCurrentTask()

		guard let nextAttempt = retriesSequence.next() else {
			logger.info("Max retries reached for request: \(request)")
			return promise.fail(SwiftkubeClientError.maxRetriesReached(request: request))
		}

		let delayMillis = nextAttempt.delay * 1000
		schedule(in: TimeAmount.milliseconds(Int64(delayMillis)))
	}

	private func stopCurrentTask() {
		clientTask?.cancel()
		clientTask = nil
	}

	/// Waits indefinitely for the execution of this task.
	///
	/// The underlying ``EventLoopFuture`` resolves either in a success upon a canceling the task,
	/// or it errors if all retry attempts are exhausted according to the ``RetryStrategy``.
	///
	/// - throws: The error value of the ``EventLoopFuture`` if it errors.
	public func wait() throws {
		try promise.futureResult.wait()
	}

	/// Cancels the task execution.
	public func cancel() {
		cancelled = true
		stopCurrentTask()
		promise.succeed(())
	}
}
