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

// MARK: - NetworkingV1Beta1API

public protocol NetworkingV1Beta1API: Sendable {

	var iPAddresses: ClusterScopedGenericKubernetesClient<networking.v1beta1.IPAddress> { get }
	var serviceCIDRs: ClusterScopedGenericKubernetesClient<networking.v1beta1.ServiceCIDR> { get }
}

/// DSL for `networking.k8s.io.v1beta1` API Group
public extension KubernetesClient {

	final class NetworkingV1Beta1: NetworkingV1Beta1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var iPAddresses: ClusterScopedGenericKubernetesClient<networking.v1beta1.IPAddress> {
			client.clusterScoped(for: networking.v1beta1.IPAddress.self)
		}

		public var serviceCIDRs: ClusterScopedGenericKubernetesClient<networking.v1beta1.ServiceCIDR> {
			client.clusterScoped(for: networking.v1beta1.ServiceCIDR.self)
		}
	}

	var networkingV1Beta1: NetworkingV1Beta1API {
		NetworkingV1Beta1(self)
	}
}
