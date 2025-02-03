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

// MARK: - CoordinationV1Alpha2API

public protocol CoordinationV1Alpha2API {

	var leaseCandidates: NamespacedGenericKubernetesClient<coordination.v1alpha2.LeaseCandidate> { get }
}

/// DSL for `coordination.k8s.io.v1alpha2` API Group
public extension KubernetesClient {

	class CoordinationV1Alpha2: CoordinationV1Alpha2API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var leaseCandidates: NamespacedGenericKubernetesClient<coordination.v1alpha2.LeaseCandidate> {
			client.namespaceScoped(for: coordination.v1alpha2.LeaseCandidate.self)
		}
	}

	var coordinationV1Alpha2: CoordinationV1Alpha2API {
		CoordinationV1Alpha2(self)
	}
}
