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
import NIO
import NIOHTTP1
import SwiftkubeModel

// MARK: - KubernetesRequest

/// Represents a request against Kubernetes API Server
public struct KubernetesRequest {

	/// API URL for this request.
	let url: URL
	/// The ``HTTPMethod`` for this request.
	let method: HTTPMethod
	/// The ``HTTPHeaders`` for this request.
	var headers: HTTPHeaders
	/// Optional ``RequestBody`` for this request.
	let body: RequestBody?
	/// Optional ``meta.v1.DeleteOptions`` in case of a `DELETE` request.
	let deleteOptions: meta.v1.DeleteOptions?

	internal var resourceVersion: String? {
		get {
			headers.first(name: "resourceVersion")
		}
		set {
			headers.remove(name: "resourceVersion")
			if newValue != nil {
				headers.add(name: "resourceVersion", value: newValue!)
			}
		}
	}

	internal func asClientRequest() throws -> HTTPClient.Request {
		try HTTPClient.Request(
			url: url,
			method: method,
			headers: headers,
			body: buildSyncBody()
		)
	}

	internal func asAsyncClientRequest() throws -> HTTPClientRequest {
		var request = HTTPClientRequest(url: url.absoluteString)
		request.method = method
		request.headers = headers
		request.body = try buildAsyncBody()
		return request
	}

	private func buildSyncBody() throws -> HTTPClient.Body? {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		if let requestBody = body {
			let data = try requestBody.payload.encode(encoder: encoder)
			return .bytes(data)
		}

		if let options = deleteOptions {
			let data = try encoder.encode(options)
			return .bytes(data)
		}

		return nil
	}

	private func buildAsyncBody() throws -> HTTPClientRequest.Body? {
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		if let requestBody = body {
			let data = try requestBody.payload.encode(encoder: encoder)
			return .bytes(data)
		}

		if let options = deleteOptions {
			let data = try encoder.encode(options)
			return .bytes(data)
		}

		return nil
	}
}

// MARK: - RequestBody

internal enum RequestBody {
	case resource(payload: any KubernetesAPIResource)
	case subResource(type: ResourceType, payload: any KubernetesResource)

	var type: ResourceType {
		switch self {
		case .resource:
			return .root
		case let .subResource(type: subType, payload: _):
			return subType
		}
	}

	var payload: any KubernetesResource {
		switch self {
		case let .resource(payload: payload):
			return payload
		case let .subResource(type: _, payload: payload):
			return payload
		}
	}
}

private extension KubernetesResource {
	func encode(encoder: JSONEncoder) throws -> Data {
		try encoder.encode(self)
	}
}
