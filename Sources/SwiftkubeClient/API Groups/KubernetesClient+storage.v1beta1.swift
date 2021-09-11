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

// MARK: - StorageV1Beta1API

public protocol StorageV1Beta1API {

	var csiDrivers: ClusterScopedGenericKubernetesClient<storage.v1beta1.CSIDriver> { get }
	var csiNodes: ClusterScopedGenericKubernetesClient<storage.v1beta1.CSINode> { get }
	var storageClasses: ClusterScopedGenericKubernetesClient<storage.v1beta1.StorageClass> { get }
	var volumeAttachments: ClusterScopedGenericKubernetesClient<storage.v1beta1.VolumeAttachment> { get }
}

/// DSL for `storage.k8s.io.v1beta1` API Group
public extension KubernetesClient {

	class StorageV1Beta1: StorageV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var csiDrivers: ClusterScopedGenericKubernetesClient<storage.v1beta1.CSIDriver> {
			client.clusterScoped(for: storage.v1beta1.CSIDriver.self)
		}

		public var csiNodes: ClusterScopedGenericKubernetesClient<storage.v1beta1.CSINode> {
			client.clusterScoped(for: storage.v1beta1.CSINode.self)
		}

		public var storageClasses: ClusterScopedGenericKubernetesClient<storage.v1beta1.StorageClass> {
			client.clusterScoped(for: storage.v1beta1.StorageClass.self)
		}

		public var volumeAttachments: ClusterScopedGenericKubernetesClient<storage.v1beta1.VolumeAttachment> {
			client.clusterScoped(for: storage.v1beta1.VolumeAttachment.self)
		}
	}

	var storageV1Beta1: StorageV1Beta1API {
		StorageV1Beta1(self)
	}
}
