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

// MARK: - ResourceEventTransformer

internal struct ResourceEventTransformer<Resource: KubernetesAPIResource>: DataStreamerTransformer {

	private let decoder: JSONDecoder

	init(decoder: JSONDecoder) {
		self.decoder = decoder
	}

	func transform(input: String) -> Result<WatchEvent<Resource>, any Error> {
		guard
			let data = input.data(using: .utf8),
			let event = try? decoder.decode(meta.v1.WatchEvent.self, from: data)
		else {
			return .failure(SwiftkubeClientError.decodingError("Error decoding meta.v1.WatchEvent payload"))
		}

		guard let eventType = EventType(rawValue: event.type) else {
			return .failure(SwiftkubeClientError.decodingError("Error parsing EventType"))
		}

		guard
			let jsonData = try? JSONSerialization.data(withJSONObject: event.object.properties),
			let resource = try? decoder.decode(Resource.self, from: jsonData)
		else {
			return .failure(SwiftkubeClientError.decodingError("Error deserializing \(String(describing: Resource.self))"))
		}

		let watchEvent = WatchEvent(type: eventType, resource: resource)
		return .success(watchEvent)
	}
}
