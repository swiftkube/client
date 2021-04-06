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

// MARK: - FlowControlV1Alpha1API

public protocol FlowControlV1Alpha1API {

	var priorityLevelConfigurations: ClusterScopedGenericKubernetesClient<flowcontrol.v1alpha1.PriorityLevelConfiguration> { get }

	var flowSchemas: ClusterScopedGenericKubernetesClient<flowcontrol.v1alpha1.FlowSchema> { get }
}

/// DSL for `flowcontrol.v1alpha1` API Group
public extension KubernetesClient {

	class FlowControlV1Alpha1: FlowControlV1Alpha1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var priorityLevelConfigurations: ClusterScopedGenericKubernetesClient<flowcontrol.v1alpha1.PriorityLevelConfiguration> {
			client.clusterScoped(for: flowcontrol.v1alpha1.PriorityLevelConfiguration.self)
		}

		public var flowSchemas: ClusterScopedGenericKubernetesClient<flowcontrol.v1alpha1.FlowSchema> {
			client.clusterScoped(for: flowcontrol.v1alpha1.FlowSchema.self)
		}
	}

	var flowControlV1Alpha1: FlowControlV1Alpha1API {
		FlowControlV1Alpha1(self)
	}
}
