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

// MARK: - CoordinationV1API

public protocol CoordinationV1API {

	var leases: NamespacedGenericKubernetesClient<coordination.v1.Lease> { get }
}

/// DSL for `coordination.v1` API Group
public extension KubernetesClient {

	class CoordinationV1: CoordinationV1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var leases: NamespacedGenericKubernetesClient<coordination.v1.Lease> {
			client.namespaceScoped(for: coordination.v1.Lease.self)
		}
	}

	var coordinationV1: CoordinationV1API {
		CoordinationV1(self)
	}
}
