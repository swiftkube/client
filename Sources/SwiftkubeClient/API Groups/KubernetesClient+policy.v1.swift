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

// MARK: - PolicyV1API

public protocol PolicyV1API: Sendable {

	var podDisruptionBudgets: NamespacedGenericKubernetesClient<policy.v1.PodDisruptionBudget> { get }
}

/// DSL for `policy.v1` API Group
public extension KubernetesClient {

	final class PolicyV1: PolicyV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var podDisruptionBudgets: NamespacedGenericKubernetesClient<policy.v1.PodDisruptionBudget> {
			client.namespaceScoped(for: policy.v1.PodDisruptionBudget.self)
		}
	}

	var policyV1: PolicyV1API {
		PolicyV1(self)
	}
}
