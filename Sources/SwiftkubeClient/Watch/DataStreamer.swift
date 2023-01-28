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
import NIOFoundationCompat

// MARK: - DataStreamerType

internal protocol DataStreamerType {
	associatedtype Element

	func doStream(response: HTTPClientResponse, logger: Logger) -> AsyncThrowingStream<Element, Error>
	func process(data: Data, continuation: AsyncThrowingStream<Element, Error>.Continuation)
}

// MARK: - DataStreamer

internal class DataStreamer<Output>: DataStreamerType {

	private var task: Task<Void, Error>?

	func doStream(response: HTTPClientResponse, logger: Logger) -> AsyncThrowingStream<Output, Error> {
		AsyncThrowingStream<Element, Error>(bufferingPolicy: .unbounded) { continuation in
			task = makeTask(response: response, continuation: continuation, logger: logger)
		}
	}

	private func makeTask(
		response: HTTPClientResponse,
		continuation: AsyncThrowingStream<Output, Error>.Continuation,
		logger: Logger
	) -> Task<Void, Error> {
		Task {
			guard !Task.isCancelled else {
				logger.debug("DataStreamer for response: \(response) was cancelled")
				continuation.finish()
				return
			}

			var streamingBuffer: ByteBuffer = ByteBuffer()
			do {
				for try await buffer in response.body {
					guard !Task.isCancelled else {
						logger.debug("DataStreamer for response: \(response) was cancelled")
						continuation.finish()
						break
					}

					var varBuffer = buffer
					streamingBuffer.writeBuffer(&varBuffer)

					let line = streamingBuffer.withUnsafeReadableBytes { raw in
						raw.firstIndex(of: UInt8(0x0A))
					}

					guard
						let readableLine = line,
						let data = streamingBuffer.readData(length: readableLine + 1)
					else {
						return continuation.finish()
					}

					process(data: data, continuation: continuation)
				}

				continuation.finish()
			} catch {
				logger.debug("Error occurred: \(error.localizedDescription)")
				continuation.finish(throwing: error)
			}
		}
	}

	func process(data: Data, continuation: AsyncThrowingStream<Output, Error>.Continuation) {
		fatalError("Should only be used from a subclass")
	}

	func cancel() {
		task?.cancel()
	}
}
