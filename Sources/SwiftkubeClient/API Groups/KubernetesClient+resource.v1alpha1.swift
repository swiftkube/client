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

// MARK: - ResourceV1Alpha1API

public protocol ResourceV1Alpha1API {

	var podSchedulings: NamespacedGenericKubernetesClient<resource.v1alpha1.PodScheduling> { get }
	var resourceClaims: NamespacedGenericKubernetesClient<resource.v1alpha1.ResourceClaim> { get }
	var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1alpha1.ResourceClaimTemplate> { get }
	var resourceClasses: ClusterScopedGenericKubernetesClient<resource.v1alpha1.ResourceClass> { get }
}

/// DSL for `resource.k8s.io.v1alpha1` API Group
public extension KubernetesClient {

	class ResourceV1Alpha1: ResourceV1Alpha1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var podSchedulings: NamespacedGenericKubernetesClient<resource.v1alpha1.PodScheduling> {
			client.namespaceScoped(for: resource.v1alpha1.PodScheduling.self)
		}

		public var resourceClaims: NamespacedGenericKubernetesClient<resource.v1alpha1.ResourceClaim> {
			client.namespaceScoped(for: resource.v1alpha1.ResourceClaim.self)
		}

		public var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1alpha1.ResourceClaimTemplate> {
			client.namespaceScoped(for: resource.v1alpha1.ResourceClaimTemplate.self)
		}

		public var resourceClasses: ClusterScopedGenericKubernetesClient<resource.v1alpha1.ResourceClass> {
			client.clusterScoped(for: resource.v1alpha1.ResourceClass.self)
		}
	}

	var resourceV1Alpha1: ResourceV1Alpha1API {
		ResourceV1Alpha1(self)
	}
}
