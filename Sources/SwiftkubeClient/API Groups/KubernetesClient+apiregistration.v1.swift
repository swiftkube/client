//
// Copyright 2025 Swiftkube Project
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
import SwiftkubeModel

// MARK: - APIRegistrationV1API

public protocol APIRegistrationV1API: Sendable {

	var apiServices: ClusterScopedGenericKubernetesClient<apiregistration.v1.APIService> { get }
}

/// DSL for `apiregistration.k8s.io.v1` API Group
public extension KubernetesClient {

	final class APIRegistrationV1: APIRegistrationV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var apiServices: ClusterScopedGenericKubernetesClient<apiregistration.v1.APIService> {
			client.clusterScoped(for: apiregistration.v1.APIService.self)
		}
	}

	var apiRegistrationV1: APIRegistrationV1API {
		APIRegistrationV1(self)
	}
}
