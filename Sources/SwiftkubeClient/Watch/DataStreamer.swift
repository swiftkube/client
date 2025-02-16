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

// MARK: - DataStreamerTransformer

protocol DataStreamerTransformer: Sendable {
	associatedtype Element: Sendable

	func transform(input: String) -> Result<Element, Error>
}

// MARK: - DataStreamer

internal actor DataStreamer<T: DataStreamerTransformer>: Sendable where T.Element: Sendable {

	private var task: Task<Void, Error>?
	private let transformer: T

	internal init(transformer: consuming T) {
		self.transformer = transformer
	}

	func doStream(response: consuming HTTPClientResponse, logger: Logger) -> AsyncThrowingStream<T.Element, Error> {
		AsyncThrowingStream<T.Element, Error>(bufferingPolicy: .unbounded) { continuation in
			self.task = makeTask(response: response, continuation: continuation, logger: logger)
		}
	}

	private func makeTask(
		response: HTTPClientResponse,
		continuation: AsyncThrowingStream<T.Element, Error>.Continuation,
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

					let lines = streamingBuffer.withUnsafeReadableBytes { raw in
						raw.lastIndex(of: UInt8(0x0A))
					}

					guard
						let readableLines = lines,
						let data = streamingBuffer.readData(length: readableLines + 1)
					else {
						return continuation.finish()
					}

					guard let string = String(data: data, encoding: .utf8) else {
						continuation.finish(throwing: SwiftkubeClientError.decodingError("Could not deserialize payload"))
						return
					}

					string.enumerateLines { line, _ in
						let result = self.transformer.transform(input: line)
						switch result {
						case let .success(item): continuation.yield(item)
						case let .failure(error): continuation.finish(throwing: error)
						}
					}
				}

				continuation.finish()
			} catch {
				logger.debug("Error occurred: \(error.localizedDescription)")
				continuation.finish(throwing: error)
			}
		}
	}

	func cancel() {
		task?.cancel()
	}
}
