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

// MARK: - ResourceV1API

public protocol ResourceV1API: Sendable {

	var deviceClasses: ClusterScopedGenericKubernetesClient<resource.v1.DeviceClass> { get }
	var resourceClaims: NamespacedGenericKubernetesClient<resource.v1.ResourceClaim> { get }
	var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1.ResourceClaimTemplate> { get }
	var resourceSlices: ClusterScopedGenericKubernetesClient<resource.v1.ResourceSlice> { get }
}

/// DSL for `resource.k8s.io.v1` API Group
public extension KubernetesClient {

	final class ResourceV1: ResourceV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var deviceClasses: ClusterScopedGenericKubernetesClient<resource.v1.DeviceClass> {
			client.clusterScoped(for: resource.v1.DeviceClass.self)
		}

		public var resourceClaims: NamespacedGenericKubernetesClient<resource.v1.ResourceClaim> {
			client.namespaceScoped(for: resource.v1.ResourceClaim.self)
		}

		public var resourceClaimTemplates: NamespacedGenericKubernetesClient<resource.v1.ResourceClaimTemplate> {
			client.namespaceScoped(for: resource.v1.ResourceClaimTemplate.self)
		}

		public var resourceSlices: ClusterScopedGenericKubernetesClient<resource.v1.ResourceSlice> {
			client.clusterScoped(for: resource.v1.ResourceSlice.self)
		}
	}

	var resourceV1: ResourceV1API {
		ResourceV1(self)
	}
}
