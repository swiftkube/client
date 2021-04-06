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

// MARK: - AutoscalingV2Beta2API

public protocol AutoscalingV2Beta2API {

	var horizontalPodAutoscalers: NamespacedGenericKubernetesClient<autoscaling.v2beta2.HorizontalPodAutoscaler> { get }
}

/// DSL for `autoscaling.v2Beta2` API Group
public extension KubernetesClient {

	class AutoscalingV2Beta2: AutoscalingV2Beta2API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var horizontalPodAutoscalers: NamespacedGenericKubernetesClient<autoscaling.v2beta2.HorizontalPodAutoscaler> {
			client.namespaceScoped(for: autoscaling.v2beta2.HorizontalPodAutoscaler.self)
		}
	}

	var autoscalingV2Beta2: AutoscalingV2Beta2API {
		AutoscalingV2Beta2(self)
	}
}
