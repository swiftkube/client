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
import NIOHTTP1
import SwiftkubeModel

/// Represents SwiftkubeClient errors.
public enum SwiftkubeClientError: Error {
	/// Thrown when the client constructs an invalid URL, e.g. when a wrong config is used.
	case invalidURL
	/// Indicates a bad request made by the client, e.g. creating an object wihtout a name.
	case badRequest(String)
	/// Thrown when receiving an empty response when content is expected.
	case emptyResponse
	/// Indicates all response decoding errors.
	case decodingError(String)
	/// Thrown on all  errors returned from the Kubernetes API server.
	case requestError(meta.v1.Status)

	internal static func methodNotAllowed(_ method: HTTPMethod) -> SwiftkubeClientError {
		let status = sk.status {
			$0.code = 405
			$0.status = "Failure"
			$0.reason = "MethodNotAllowed"
			$0.message = "\(method) is not supported for this resource"
		}

		return SwiftkubeClientError.requestError(status)
	}
}
