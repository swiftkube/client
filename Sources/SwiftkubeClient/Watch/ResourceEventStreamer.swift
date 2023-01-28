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

// MARK: - ResourceEventStreamer

internal class ResourceEventStreamer<Resource: KubernetesAPIResource>: DataStreamer<WatchEvent<Resource>> {

	private let decoder: JSONDecoder

	init(decoder: JSONDecoder) {
		self.decoder = decoder
	}

	internal override func process(data: Data, continuation: AsyncThrowingStream<WatchEvent<Resource>, Error>.Continuation) {
		guard let string = String(data: data, encoding: .utf8) else {
			continuation.finish(throwing: SwiftkubeClientError.decodingError("Could not deserialize payload"))
			return
		}

		string.enumerateLines { line, _ in
			guard
				let data = line.data(using: .utf8),
				let event = try? self.decoder.decode(meta.v1.WatchEvent.self, from: data)
			else {
				continuation.finish(throwing: SwiftkubeClientError.decodingError("Error decoding meta.v1.WatchEvent payload"))
				return
			}

			guard let eventType = EventType(rawValue: event.type) else {
				continuation.finish(throwing: SwiftkubeClientError.decodingError("Error parsing EventType"))
				return
			}

			guard
				let jsonData = try? JSONSerialization.data(withJSONObject: event.object),
				let resource = try? self.decoder.decode(Resource.self, from: jsonData)
			else {
				continuation.finish(throwing: SwiftkubeClientError.decodingError("Error deserializing \(String(describing: Resource.self))"))
				return
			}

			continuation.yield(WatchEvent(type: eventType, resource: resource))
		}
	}
}
