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

// MARK: - ResourceV1Alpha3API

public protocol ResourceV1Alpha3API: Sendable {

	var deviceClasses: ClusterScopedGenericKubernetesClient<resource.v1alpha3.DeviceClass> { get }
	var deviceTaintRules: ClusterScopedGenericKubernetesClient<resource.v1alpha3.DeviceTaintRule> { get }
	var resourceClaims: NamespacedGenericKubernetesClient<resource.v1alpha3.ResourceClaim> { get }
	var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1alpha3.ResourceClaimTemplate> { get }
	var resourceSlices: ClusterScopedGenericKubernetesClient<resource.v1alpha3.ResourceSlice> { get }
}

/// DSL for `resource.k8s.io.v1alpha3` API Group
public extension KubernetesClient {

	final class ResourceV1Alpha3: ResourceV1Alpha3API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var deviceClasses: ClusterScopedGenericKubernetesClient<resource.v1alpha3.DeviceClass> {
			client.clusterScoped(for: resource.v1alpha3.DeviceClass.self)
		}

		public var deviceTaintRules: ClusterScopedGenericKubernetesClient<resource.v1alpha3.DeviceTaintRule> {
			client.clusterScoped(for: resource.v1alpha3.DeviceTaintRule.self)
		}

		public var resourceClaims: NamespacedGenericKubernetesClient<resource.v1alpha3.ResourceClaim> {
			client.namespaceScoped(for: resource.v1alpha3.ResourceClaim.self)
		}

		public var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1alpha3.ResourceClaimTemplate> {
			client.namespaceScoped(for: resource.v1alpha3.ResourceClaimTemplate.self)
		}

		public var resourceSlices: ClusterScopedGenericKubernetesClient<resource.v1alpha3.ResourceSlice> {
			client.clusterScoped(for: resource.v1alpha3.ResourceSlice.self)
		}
	}

	var resourceV1Alpha3: ResourceV1Alpha3API {
		ResourceV1Alpha3(self)
	}
}
