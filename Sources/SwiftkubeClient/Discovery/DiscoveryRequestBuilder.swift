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

// MARK: - RequestBuilder

///
/// An internal class for building API request objects.
///
/// It assumes a correct usage and does only minimal sanity checks.
internal class DiscoveryRequestBuilder {

	let config: KubernetesClientConfig
	var path: String!
	var components: URLComponents?

	init(config: KubernetesClientConfig) {
		self.config = config
		self.components = URLComponents(url: config.masterURL, resolvingAgainstBaseURL: false)
	}

	func path(_ path: String) -> DiscoveryRequestBuilder {
		self.path = path
		return self
	}

	func build() throws -> KubernetesRequest {
		let method = HTTPMethod.GET
		components?.path = path

		if (components?.url?.absoluteString) == nil {
			throw SwiftkubeClientError.invalidURL
		}

		let headers = buildHeaders(withAuthentication: config.authentication)
		return KubernetesRequest(
			url: (components?.url)!,
			method: method,
			headers: headers,
			body: nil,
			deleteOptions: nil
		)
	}

	func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
		var headers: [(String, String)] = []
		if let authorizationHeader = authentication?.authorizationHeader() {
			headers.append(("Authorization", authorizationHeader))
		}

		return HTTPHeaders(headers)
	}
}
