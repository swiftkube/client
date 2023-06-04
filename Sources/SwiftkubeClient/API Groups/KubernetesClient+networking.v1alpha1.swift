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

// MARK: - NetworkingV1Alpha1API

public protocol NetworkingV1Alpha1API {

	var clusterCIDRs: ClusterScopedGenericKubernetesClient<networking.v1alpha1.ClusterCIDR> { get }
}

/// DSL for `networking.k8s.io.v1alpha1` API Group
public extension KubernetesClient {

	class NetworkingV1Alpha1: NetworkingV1Alpha1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var clusterCIDRs: ClusterScopedGenericKubernetesClient<networking.v1alpha1.ClusterCIDR> {
			client.clusterScoped(for: networking.v1alpha1.ClusterCIDR.self)
		}
	}

	var networkingV1Alpha1: NetworkingV1Alpha1API {
		NetworkingV1Alpha1(self)
	}
}
