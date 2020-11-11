//
// Copyright 2020 Iskandar Abudiab (iabudiab.dev)
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

public enum EventType: String, RawRepresentable {
	case added = "ADDED"
	case modified = "MODIFIED"
	case deleted = "DELETED"
	case error = "ERROR"
}

protocol Watcher {
	func handle(payload: Data)
}

final public class ResourceWatch<Resource: KubernetesAPIResource>: Watcher {

	public typealias EventHandler = (EventType, Resource) -> Void

	private let decoder = JSONDecoder()
	private let handler: EventHandler
	private let logger: Logger

	init(logger: Logger? = nil, _ handler: @escaping EventHandler) {
		self.handler = handler
		self.logger = logger ?? KubernetesClient.loggingDisabled
	}

	internal func handle(payload: Data) {
		guard let string = String(data: payload, encoding: .utf8) else {
			logger.warning("Could not deserialize payload")
			return
		}

		string.enumerateLines { (line, _) in
			guard
				let data = line.data(using: .utf8),
				let event = try? self.decoder.decode(meta.v1.WatchEvent.self, from: data)
			else {
				self.logger.warning("Error decoding meta.v1.WatchEvent payload")
				return
			}

			guard let eventType = EventType(rawValue: event.type) else {
				self.logger.warning("Error parsing EventType")
				return
			}

			guard
				let jsonData = try? JSONSerialization.data(withJSONObject: event.object),
				let resource = try?	self.decoder.decode(Resource.self, from: jsonData)
			else {
				self.logger.warning("Error deserializing \(String(describing: Resource.self))")
				return
			}

			self.handler(eventType, resource)
		}
	}
}

final public class LogWatch: Watcher {

	public typealias LineHandler = (String) -> Void

	private let logger: Logger
	private let lineHandler: LineHandler

	public init(logger: Logger? = nil, lineHandler: @escaping LineHandler = { line in print(line) }) {
		self.logger = logger ?? KubernetesClient.loggingDisabled
		self.lineHandler = lineHandler
	}

	internal func handle(payload: Data) {
		guard let string = String(data: payload, encoding: .utf8) else {
			logger.warning("Could not deserialize payload")
			return
		}

		string.enumerateLines { (line, _) in
			self.lineHandler(line)
		}
	}
}

internal class WatchDelegate: HTTPClientResponseDelegate {
	typealias Response = Void

	private let watch: Watcher
	private let logger: Logger

	init(watch: Watcher, logger: Logger) {
		self.watch = watch
		self.logger = logger
	}

	func didSendRequestHead(task: HTTPClient.Task<Response>, _ head: HTTPRequestHead) {
		logger.debug("Did send request head: \(head.headers)")
	}

	func didSendRequestPart(task: HTTPClient.Task<Response>, _ part: IOData) {
		logger.debug("Did send request part: \(part)")
	}

	func didSendRequest(task: HTTPClient.Task<Response>) {
		logger.debug("Did send request: \(task)")
	}

	func didReceiveHead(task: HTTPClient.Task<Response>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
		logger.debug("Did receive response head: \(head.headers)")
		return task.eventLoop.makeSucceededFuture(())
	}

	func didReceiveBodyPart(task: HTTPClient.Task<Response>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
		logger.debug("Did receive body part: \(task)")
		let payload = Data(buffer: buffer)
		watch.handle(payload: payload)
		return task.eventLoop.makeSucceededFuture(())
	}

	func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Void {
		logger.debug("Did finish request: \(task)")
		return ()
	}

	func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
		logger.warning("Did receive error: \(error.localizedDescription)")
	}
}
