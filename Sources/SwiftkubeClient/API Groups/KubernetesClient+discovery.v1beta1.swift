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

// MARK: - DiscoveryV1Beta1API

public protocol DiscoveryV1Beta1API {

	var endpointSlices: NamespacedGenericKubernetesClient<discovery.v1beta1.EndpointSlice> { get }
}

/// DSL for `discovery.k8s.io.v1beta1` API Group
public extension KubernetesClient {

	class DiscoveryV1Beta1: DiscoveryV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var endpointSlices: NamespacedGenericKubernetesClient<discovery.v1beta1.EndpointSlice> {
			client.namespaceScoped(for: discovery.v1beta1.EndpointSlice.self)
		}
	}

	var discoveryV1Beta1: DiscoveryV1Beta1API {
		DiscoveryV1Beta1(self)
	}
}
