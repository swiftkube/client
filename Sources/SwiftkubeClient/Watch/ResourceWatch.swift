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

// MARK: - EventType

public enum EventType: String, RawRepresentable {
	case added = "ADDED"
	case modified = "MODIFIED"
	case deleted = "DELETED"
	case error = "ERROR"
}

// MARK: - Watcher

public protocol Watcher {
	typealias ErrorHandler = (SwiftkubeClientError) -> Void

	func onError(error: SwiftkubeClientError)
	func onNext(payload: Data)
}

// MARK: - ResourceWatch

open class ResourceWatch<Resource: KubernetesAPIResource>: Watcher {

	public typealias EventHandler = (EventType, Resource) -> Void

	private let decoder: JSONDecoder
	private let errorHandler: ErrorHandler?
	private let eventHandler: EventHandler

	public init(
		decoder: JSONDecoder = JSONDecoder(),
		onError errorHandler: ErrorHandler? = nil,
		onEvent eventHandler: @escaping EventHandler
	) {
		self.decoder = decoder
		self.errorHandler = errorHandler
		self.eventHandler = eventHandler
	}

	public func onError(error: SwiftkubeClientError) {
		errorHandler?(error)
	}

	public func onNext(payload: Data) {
		guard let string = String(data: payload, encoding: .utf8) else {
			errorHandler?(.decodingError("Could not deserialize payload"))
			return
		}

		string.enumerateLines { line, _ in
			guard
				let data = line.data(using: .utf8),
				let event = try? self.decoder.decode(meta.v1.WatchEvent.self, from: data)
			else {
				self.errorHandler?(.decodingError("Error decoding meta.v1.WatchEvent payload"))
				return
			}

			guard let eventType = EventType(rawValue: event.type) else {
				self.errorHandler?(.decodingError("Error parsing EventType"))
				return
			}

			guard
				let jsonData = try? JSONSerialization.data(withJSONObject: event.object),
				let resource = try? self.decoder.decode(Resource.self, from: jsonData)
			else {
				self.errorHandler?(.decodingError("Error deserializing \(String(describing: Resource.self))"))
				return
			}

			self.eventHandler(eventType, resource)
		}
	}
}

// MARK: - LogWatch

open class LogWatch: Watcher {

	public typealias LineHandler = (String) -> Void

	private let errorHandler: ErrorHandler?
	private let lineHandler: LineHandler

	public init(
		onError errorHandler: ErrorHandler? = nil,
		onNext lineHandler: @escaping LineHandler
	) {
		self.errorHandler = errorHandler
		self.lineHandler = lineHandler
	}

	public func onError(error: SwiftkubeClientError) {
		errorHandler?(error)
	}

	public func onNext(payload: Data) {
		guard let string = String(data: payload, encoding: .utf8) else {
			errorHandler?(.decodingError("Could not deserialize payload"))
			return
		}

		string.enumerateLines { line, _ in
			self.lineHandler(line)
		}
	}
}

// MARK: - WatchDelegate

internal class WatchDelegate: HTTPClientResponseDelegate {

	typealias Response = Void

	private let watcher: Watcher
	private let logger: Logger

	init(watcher: Watcher, logger: Logger) {
		self.watcher = watcher
		self.logger = logger
	}

	func didReceiveHead(task: HTTPClient.Task<Response>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
		logger.debug("Did receive response head: \(head.headers)")
		switch head.status.code {
		case HTTPResponseStatus.badRequest.code:
			watcher.onError(error: .badRequest(head.status.reasonPhrase))
		default:
			watcher.onError(error: .emptyResponse)
		}

		return task.eventLoop.makeSucceededFuture(())
	}

	func didReceiveBodyPart(task: HTTPClient.Task<Response>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
		logger.debug("Did receive body part: \(task)")
		let payload = Data(buffer: buffer)
		watcher.onNext(payload: payload)
		return task.eventLoop.makeSucceededFuture(())
	}

	func didFinishRequest(task: HTTPClient.Task<Response>) throws {
		logger.debug("Did finish request: \(task)")
		return ()
	}

	func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
		logger.debug("Did receive error: \(error.localizedDescription)")
		watcher.onError(error: .clientError(error))
	}
}
