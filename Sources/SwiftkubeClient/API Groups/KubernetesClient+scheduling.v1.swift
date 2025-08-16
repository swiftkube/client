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

// MARK: - SchedulingV1API

public protocol SchedulingV1API: Sendable {

	var priorityClasses: ClusterScopedGenericKubernetesClient<scheduling.v1.PriorityClass> { get }
}

/// DSL for `scheduling.k8s.io.v1` API Group
public extension KubernetesClient {

	final class SchedulingV1: SchedulingV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var priorityClasses: ClusterScopedGenericKubernetesClient<scheduling.v1.PriorityClass> {
			client.clusterScoped(for: scheduling.v1.PriorityClass.self)
		}
	}

	var schedulingV1: SchedulingV1API {
		SchedulingV1(self)
	}
}
