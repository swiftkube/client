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

// MARK: - NetworkingV1API

public protocol NetworkingV1API: Sendable {

	var iPAddresses: ClusterScopedGenericKubernetesClient<networking.v1.IPAddress> { get }
	var ingresses: NamespacedGenericKubernetesClient<networking.v1.Ingress> { get }
	var ingressClasses: ClusterScopedGenericKubernetesClient<networking.v1.IngressClass> { get }
	var networkPolicies: NamespacedGenericKubernetesClient<networking.v1.NetworkPolicy> { get }
	var serviceCIDRs: ClusterScopedGenericKubernetesClient<networking.v1.ServiceCIDR> { get }
}

/// DSL for `networking.k8s.io.v1` API Group
public extension KubernetesClient {

	final class NetworkingV1: NetworkingV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var iPAddresses: ClusterScopedGenericKubernetesClient<networking.v1.IPAddress> {
			client.clusterScoped(for: networking.v1.IPAddress.self)
		}

		public var ingresses: NamespacedGenericKubernetesClient<networking.v1.Ingress> {
			client.namespaceScoped(for: networking.v1.Ingress.self)
		}

		public var ingressClasses: ClusterScopedGenericKubernetesClient<networking.v1.IngressClass> {
			client.clusterScoped(for: networking.v1.IngressClass.self)
		}

		public var networkPolicies: NamespacedGenericKubernetesClient<networking.v1.NetworkPolicy> {
			client.namespaceScoped(for: networking.v1.NetworkPolicy.self)
		}

		public var serviceCIDRs: ClusterScopedGenericKubernetesClient<networking.v1.ServiceCIDR> {
			client.clusterScoped(for: networking.v1.ServiceCIDR.self)
		}
	}

	var networkingV1: NetworkingV1API {
		NetworkingV1(self)
	}
}
