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
import Metrics

internal extension KubernetesClient {

	static func updateMetrics(startTime: UInt64, request: HTTPClient.Request, result: Result<HTTPClient.Response, Error>) {
		let method = request.method.rawValue
		let path = request.url.path

		switch result {
		case let .success(response):
			let statusCode = response.status.code
			let counterDimensions = [
				("method", method),
				("path", path),
				("status", statusCode.description),
			]

			Counter(label: "sk_http_requests_total", dimensions: counterDimensions).increment()
			if statusCode >= 500 {
				Counter(label: "sk_http_request_errors_total", dimensions: counterDimensions).increment()
			}
		case .failure:
			let counterDimensions = [
				("method", method),
				("path", path),
			]
			Counter(label: "sk_request_errors_total", dimensions: counterDimensions).increment()
		}

		Timer(
			label: "sk_http_request_duration_seconds",
			dimensions: [("method", method), ("path", path)],
			preferredDisplayUnit: .seconds
		)
		.recordNanoseconds(DispatchTime.now().uptimeNanoseconds - startTime)
	}
}
