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
import SwiftkubeModel

// MARK: - APIRegistrationV1Beta1API

public protocol APIRegistrationV1Beta1API {

	var apiServices: ClusterScopedGenericKubernetesClient<apiregistration.v1beta1.APIService> { get }
}

/// DSL for `apiregistrationV1Beta1` API Group
public extension KubernetesClient {

	class APIRegistrationV1Beta1: APIRegistrationV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var apiServices: ClusterScopedGenericKubernetesClient<apiregistration.v1beta1.APIService> {
			client.clusterScoped(for: apiregistration.v1beta1.APIService.self)
		}
	}

	var apiRegistrationV1Beta1: APIRegistrationV1Beta1API {
		APIRegistrationV1Beta1(self)
	}
}
