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

// MARK: - FlowControlV1Beta2API

public protocol FlowControlV1Beta2API {

	var flowSchemas: ClusterScopedGenericKubernetesClient<flowcontrol.v1beta2.FlowSchema> { get }
	var priorityLevelConfigurations: ClusterScopedGenericKubernetesClient<flowcontrol.v1beta2.PriorityLevelConfiguration> { get }
}

/// DSL for `flowcontrol.apiserver.k8s.io.v1beta2` API Group
public extension KubernetesClient {

	class FlowControlV1Beta2: FlowControlV1Beta2API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var flowSchemas: ClusterScopedGenericKubernetesClient<flowcontrol.v1beta2.FlowSchema> {
			client.clusterScoped(for: flowcontrol.v1beta2.FlowSchema.self)
		}

		public var priorityLevelConfigurations: ClusterScopedGenericKubernetesClient<flowcontrol.v1beta2.PriorityLevelConfiguration> {
			client.clusterScoped(for: flowcontrol.v1beta2.PriorityLevelConfiguration.self)
		}
	}

	var flowControlV1Beta2: FlowControlV1Beta2API {
		FlowControlV1Beta2(self)
	}
}
