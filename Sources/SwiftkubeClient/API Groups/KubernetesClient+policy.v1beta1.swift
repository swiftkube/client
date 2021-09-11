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

// MARK: - PolicyV1Beta1API

public protocol PolicyV1Beta1API {

	var podDisruptionBudgets: NamespacedGenericKubernetesClient<policy.v1beta1.PodDisruptionBudget> { get }
	var podSecurityPolicies: ClusterScopedGenericKubernetesClient<policy.v1beta1.PodSecurityPolicy> { get }
}

/// DSL for `policy.v1beta1` API Group
public extension KubernetesClient {

	class PolicyV1Beta1: PolicyV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var podDisruptionBudgets: NamespacedGenericKubernetesClient<policy.v1beta1.PodDisruptionBudget> {
			client.namespaceScoped(for: policy.v1beta1.PodDisruptionBudget.self)
		}

		public var podSecurityPolicies: ClusterScopedGenericKubernetesClient<policy.v1beta1.PodSecurityPolicy> {
			client.clusterScoped(for: policy.v1beta1.PodSecurityPolicy.self)
		}
	}

	var policyV1Beta1: PolicyV1Beta1API {
		PolicyV1Beta1(self)
	}
}
