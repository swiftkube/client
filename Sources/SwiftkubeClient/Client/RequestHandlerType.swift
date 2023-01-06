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

// MARK: - RequestHandlerType

internal protocol RequestHandlerType {

	var httpClient: HTTPClient { get }
	var config: KubernetesClientConfig { get }
	var jsonDecoder: JSONDecoder { get }
	var logger: Logger { get }

	func prepareDecoder(_ decoder: JSONDecoder)
}

// MARK: - RequestHandlerType + Prepare

extension RequestHandlerType {
	func prepareDecoder(_ decoder: JSONDecoder) {
		// NOOP
	}
}

// MARK: - RequestHandlerType

internal extension RequestHandlerType {

	func dispatch<T: Decodable>(request: KubernetesRequest, expect responseType: T.Type) async throws -> T {
		let startTime = DispatchTime.now().uptimeNanoseconds
		let clientRequest = try request.asAsyncClientRequest()

		do {
			let response = try await httpClient.execute(clientRequest, timeout: config.timeout.read ?? .seconds(30), logger: logger)
			KubernetesClient.updateSucessMetrics(startTime: startTime, request: request, response: response)

			let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)

			let byteBuffer: ByteBuffer
			do {
				byteBuffer = try await response.body.collect(upTo: expectedBytes ?? 10 * 1024 * 1024)
			} catch {
				throw SwiftkubeClientError.clientError(error)
			}

			if byteBuffer.readableBytes == 0 {
				throw SwiftkubeClientError.emptyResponse
			}

			let data = Data(buffer: byteBuffer)

			guard (200 ..< 400) ~= response.status.code else {
				guard let status = try? jsonDecoder.decode(meta.v1.Status.self, from: data) else {
					throw SwiftkubeClientError.unexpectedError(data)
				}

				throw SwiftkubeClientError.statusError(status)
			}

			prepareDecoder(jsonDecoder)

			guard let resource = try? jsonDecoder.decode(T.self, from: data) else {
				throw SwiftkubeClientError.decodingError("Couldn't decode response")
			}

			return resource
		} catch {
			KubernetesClient.updateFailureMetrics(startTime: startTime, request: request)
			throw error
		}
	}

	func dispatch(request: KubernetesRequest) async throws -> String {
		let startTime = DispatchTime.now().uptimeNanoseconds
		let clientRequest = try request.asAsyncClientRequest()

		do {
			let response = try await httpClient.execute(clientRequest, timeout: config.timeout.read ?? .seconds(30), logger: logger)
			KubernetesClient.updateSucessMetrics(startTime: startTime, request: request, response: response)

			let expectedBytes = response.headers.first(name: "content-length").flatMap(Int.init)

			let byteBuffer: ByteBuffer
			do {
				byteBuffer = try await response.body.collect(upTo: expectedBytes ?? 1 * 1024 * 1024)
			} catch {
				throw SwiftkubeClientError.clientError(error)
			}

			if byteBuffer.readableBytes == 0 {
				throw SwiftkubeClientError.emptyResponse
			}

			let data = Data(buffer: byteBuffer)

			guard (200 ..< 400) ~= response.status.code else {
				guard let status = try? jsonDecoder.decode(meta.v1.Status.self, from: data) else {
					throw SwiftkubeClientError.unexpectedError(data)
				}

				throw SwiftkubeClientError.statusError(status)
			}

			guard let text = String(data: data, encoding: .utf8) else {
				throw SwiftkubeClientError.decodingError("Couldn't decode response")
			}

			return text
		} catch {
			KubernetesClient.updateFailureMetrics(startTime: startTime, request: request)
			throw error
		}
	}
}
