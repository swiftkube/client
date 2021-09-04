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

import Foundation
import Logging
import SwiftkubeModel

// MARK: - EventType

public enum EventType: String, RawRepresentable, Equatable {
	case added = "ADDED"
	case modified = "MODIFIED"
	case deleted = "DELETED"
	case error = "ERROR"
}

// MARK: - ResourceWatcherDelegate

public protocol ResourceWatcherDelegate {
	associatedtype Resource: KubernetesAPIResource

	func onEvent(event: EventType, resource: Resource)
	func onError(error: SwiftkubeClientError)
}

// MARK: - ResourceWatcher

final internal class ResourceWatcher<Delegate: ResourceWatcherDelegate>: Watcher {

	private let decoder: JSONDecoder
	private let delegate: Delegate

	init(
		decoder: JSONDecoder = JSONDecoder(),
		delegate: Delegate
	) {
		self.decoder = decoder
		self.delegate = delegate
	}

	func onError(error: SwiftkubeClientError) {
		delegate.onError(error: error)
	}

	func onNext(payload: Data) {
		guard let string = String(data: payload, encoding: .utf8) else {
			delegate.onError(error: .decodingError("Could not deserialize payload"))
			return
		}

		string.enumerateLines { line, _ in
			guard
				let data = line.data(using: .utf8),
				let event = try? self.decoder.decode(meta.v1.WatchEvent.self, from: data)
			else {
				self.delegate.onError(error: .decodingError("Error decoding meta.v1.WatchEvent payload"))
				return
			}

			guard let eventType = EventType(rawValue: event.type) else {
				self.delegate.onError(error: .decodingError("Error parsing EventType"))
				return
			}

			guard
				let jsonData = try? JSONSerialization.data(withJSONObject: event.object),
				let resource = try? self.decoder.decode(Delegate.Resource.self, from: jsonData)
			else {
				self.delegate.onError(error: .decodingError("Error deserializing \(String(describing: Delegate.Resource.self))"))
				return
			}

			self.delegate.onEvent(event: eventType, resource: resource)
		}
	}
}

// MARK: - ResourceWatcherCallback

final public class ResourceWatcherCallback<Resource: KubernetesAPIResource>: ResourceWatcherDelegate {

	public typealias ErrorHandler = (SwiftkubeClientError) -> Void
	public typealias EventHandler = (EventType, Resource) -> Void

	private let errorHandler: ErrorHandler?
	private let eventHandler: EventHandler

	public init(
		onError errorHandler: ErrorHandler? = nil,
		onEvent eventHandler: @escaping EventHandler
	) {
		self.errorHandler = errorHandler
		self.eventHandler = eventHandler
	}

	public func onEvent(event: EventType, resource: Resource) {
		eventHandler(event, resource)
	}

	public func onError(error: SwiftkubeClientError) {
		errorHandler?(error)
	}
}
