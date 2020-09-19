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
import NIO
import NIOHTTP1
import SwiftkubeModel

public enum EventType: String, RawRepresentable {
	case added = "ADDED"
	case modified = "MODIFIED"
	case deleted = "DELETED"
	case error = "ERROR"
}

final public class ResourceWatch<Resource: KubernetesResource> {

	public typealias EventHandler = (EventType, Resource) -> Void

	private let decoder = JSONDecoder()
	private let handler: EventHandler

	init(_ handler: @escaping EventHandler) {
		self.handler = handler
	}

	internal func handle(payload: Data) {
		guard let string = String(data: payload, encoding: .utf8) else {
			print("Error")
			return
		}

		string.enumerateLines { (line, _) in
			guard
				let data = line.data(using: .utf8),
				let event = try? self.decoder.decode(meta.v1.WatchEvent.self, from: data)
			else {
				print("Error")
				return
			}

			guard let eventType = EventType(rawValue: event.type) else {
				print("Error")
				return
			}

			guard
				let jsonData = try? JSONSerialization.data(withJSONObject: event.object),
				let resource = try?	self.decoder.decode(Resource.self, from: jsonData)
			else {
					print("Error")
					return
			}

			self.handler(eventType, resource)
		}
	}
}

internal class WatchDelegate<Resource: KubernetesResource>: HTTPClientResponseDelegate {
	typealias Response = Void

	private let watch: ResourceWatch<Resource>

	init(watch: ResourceWatch<Resource>) {
		self.watch = watch
	}

	func didSendRequestHead(task: HTTPClient.Task<Response>, _ head: HTTPRequestHead) {
		print("didSendRequestHead: \(head.headers)")
	}

	func didSendRequestPart(task: HTTPClient.Task<Response>, _ part: IOData) {
		print("didSendRequestPart")
	}

	func didSendRequest(task: HTTPClient.Task<Response>) {
		print("didSendRequest")
	}

	func didReceiveHead(task: HTTPClient.Task<Response>, _ head: HTTPResponseHead) -> EventLoopFuture<Void> {
		print("didReceiveHead: \(head)")
		return task.eventLoop.makeSucceededFuture(())
	}

	func didReceiveBodyPart(task: HTTPClient.Task<Response>, _ buffer: ByteBuffer) -> EventLoopFuture<Void> {
		let payload = Data(buffer: buffer)
		watch.handle(payload: payload)
		return task.eventLoop.makeSucceededFuture(())
	}

	func didFinishRequest(task: HTTPClient.Task<Response>) throws -> Void {
		return ()
	}

	func didReceiveError(task: HTTPClient.Task<Response>, _ error: Error) {
		print("Error: \(error.localizedDescription)")
	}
}
