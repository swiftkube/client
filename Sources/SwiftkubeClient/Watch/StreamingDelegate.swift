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
import NIOHTTP1
import SwiftkubeModel

// MARK: - Watcher

internal protocol Watcher {
	func onError(error: SwiftkubeClientError)
	func onNext(payload: Data)
}

// MARK: - ClientStreamingDelegate

internal class ClientStreamingDelegate: HTTPClientResponseDelegate {

	typealias Response = Void

	private let watcher: Watcher
	private let logger: Logger
	private var streamingBuffer: ByteBuffer
	internal var taskDelegate: SwiftkubeClientTaskDelegate?

	init(watcher: Watcher, logger: Logger) {
		self.watcher = watcher
		self.logger = logger
		self.streamingBuffer = ByteBuffer()
	}

	func reset() {
		streamingBuffer.clear()
	}

	func didReceiveHead(task: HTTPClient.Task<Response>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
		logger.debug("Did receive response head: \(head.headers)")
		if head.status.code >= 400 {
			// TODO: Proper status handling
			watcher.onError(error: .requestError(meta.v1.Status()))
		}

		return task.eventLoop.makeSucceededFuture(())
	}

	func didReceiveBodyPart(task: HTTPClient.Task<Response>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
		logger.debug("Did receive body part: \(task)")

		var varBuffer = buffer
		streamingBuffer.writeBuffer(&varBuffer)

		let line = streamingBuffer.withUnsafeReadableBytes { raw in
			raw.firstIndex(of: UInt8(0x0A))
		}

		guard
			let readableLine = line,
			let data = streamingBuffer.readData(length: readableLine + 1)
		else {
			return task.eventLoop.makeSucceededFuture(())
		}

		watcher.onNext(payload: data)

		return task.eventLoop.makeSucceededFuture(())
	}

	func didFinishRequest(task: HTTPClient.Task<Response>) throws {
		logger.debug("Did finish request: \(task)")
		taskDelegate?.onDidFinish(task: task)
		return ()
	}

	func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
		logger.debug("Did receive error: \(error.localizedDescription)")
		watcher.onError(error: .clientError(error))
		taskDelegate?.onError(error: .clientError(error))
	}
}
