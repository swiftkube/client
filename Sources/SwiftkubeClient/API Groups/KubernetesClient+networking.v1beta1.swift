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

// MARK: - NetworkingV1Beta1API

public protocol NetworkingV1Beta1API {

	var ingressClasses: ClusterScopedGenericKubernetesClient<networking.v1beta1.IngressClass> { get }

	var ingresses: NamespacedGenericKubernetesClient<networking.v1beta1.Ingress> { get }
}

/// DSL for `networking.v1beta1` API Group
public extension KubernetesClient {

	class NetworkingV1Beta1: NetworkingV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var ingressClasses: ClusterScopedGenericKubernetesClient<networking.v1beta1.IngressClass> {
			client.clusterScoped(for: networking.v1beta1.IngressClass.self)
		}

		public var ingresses: NamespacedGenericKubernetesClient<networking.v1beta1.Ingress> {
			client.namespaceScoped(for: networking.v1beta1.Ingress.self)
		}
	}

	var networkingV1Beta1: NetworkingV1Beta1API {
		NetworkingV1Beta1(self)
	}
}
