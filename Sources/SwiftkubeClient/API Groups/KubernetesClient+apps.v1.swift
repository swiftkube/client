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

// MARK: - AppsV1API

public protocol AppsV1API: Sendable {

	var controllerRevisions: NamespacedGenericKubernetesClient<apps.v1.ControllerRevision> { get }
	var daemonSets: NamespacedGenericKubernetesClient<apps.v1.DaemonSet> { get }
	var deployments: NamespacedGenericKubernetesClient<apps.v1.Deployment> { get }
	var replicaSets: NamespacedGenericKubernetesClient<apps.v1.ReplicaSet> { get }
	var statefulSets: NamespacedGenericKubernetesClient<apps.v1.StatefulSet> { get }
}

/// DSL for `apps.v1` API Group
public extension KubernetesClient {

	final class AppsV1: AppsV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var controllerRevisions: NamespacedGenericKubernetesClient<apps.v1.ControllerRevision> {
			client.namespaceScoped(for: apps.v1.ControllerRevision.self)
		}

		public var daemonSets: NamespacedGenericKubernetesClient<apps.v1.DaemonSet> {
			client.namespaceScoped(for: apps.v1.DaemonSet.self)
		}

		public var deployments: NamespacedGenericKubernetesClient<apps.v1.Deployment> {
			client.namespaceScoped(for: apps.v1.Deployment.self)
		}

		public var replicaSets: NamespacedGenericKubernetesClient<apps.v1.ReplicaSet> {
			client.namespaceScoped(for: apps.v1.ReplicaSet.self)
		}

		public var statefulSets: NamespacedGenericKubernetesClient<apps.v1.StatefulSet> {
			client.namespaceScoped(for: apps.v1.StatefulSet.self)
		}
	}

	var appsV1: AppsV1API {
		AppsV1(self)
	}
}
