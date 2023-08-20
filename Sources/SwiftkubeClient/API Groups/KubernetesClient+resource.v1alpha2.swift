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

// MARK: - ResourceV1Alpha2API

public protocol ResourceV1Alpha2API {

	var podSchedulingContexts: NamespacedGenericKubernetesClient<resource.v1alpha2.PodSchedulingContext> { get }
	var resourceClaims: NamespacedGenericKubernetesClient<resource.v1alpha2.ResourceClaim> { get }
	var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1alpha2.ResourceClaimTemplate> { get }
	var resourceClasses: ClusterScopedGenericKubernetesClient<resource.v1alpha2.ResourceClass> { get }
}

/// DSL for `resource.k8s.io.v1alpha2` API Group
public extension KubernetesClient {

	class ResourceV1Alpha2: ResourceV1Alpha2API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var podSchedulingContexts: NamespacedGenericKubernetesClient<resource.v1alpha2.PodSchedulingContext> {
			client.namespaceScoped(for: resource.v1alpha2.PodSchedulingContext.self)
		}

		public var resourceClaims: NamespacedGenericKubernetesClient<resource.v1alpha2.ResourceClaim> {
			client.namespaceScoped(for: resource.v1alpha2.ResourceClaim.self)
		}

		public var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1alpha2.ResourceClaimTemplate> {
			client.namespaceScoped(for: resource.v1alpha2.ResourceClaimTemplate.self)
		}

		public var resourceClasses: ClusterScopedGenericKubernetesClient<resource.v1alpha2.ResourceClass> {
			client.clusterScoped(for: resource.v1alpha2.ResourceClass.self)
		}
	}

	var resourceV1Alpha2: ResourceV1Alpha2API {
		ResourceV1Alpha2(self)
	}
}
