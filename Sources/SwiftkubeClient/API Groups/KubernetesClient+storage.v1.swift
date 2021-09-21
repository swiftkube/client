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

// MARK: - StorageV1API

public protocol StorageV1API {

	var csiNodes: ClusterScopedGenericKubernetesClient<storage.v1.CSINode> { get }

	var csiDrivers: ClusterScopedGenericKubernetesClient<storage.v1.CSIDriver> { get }

	var storageClasses: ClusterScopedGenericKubernetesClient<storage.v1.StorageClass> { get }

	var volumeAttachments: ClusterScopedGenericKubernetesClient<storage.v1.VolumeAttachment> { get }
}

/// DSL for `storage.v1` API Group
public extension KubernetesClient {

	class StorageV1: StorageV1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var csiNodes: ClusterScopedGenericKubernetesClient<storage.v1.CSINode> {
			client.clusterScoped(for: storage.v1.CSINode.self)
		}

		public var csiDrivers: ClusterScopedGenericKubernetesClient<storage.v1.CSIDriver> {
			client.clusterScoped(for: storage.v1.CSIDriver.self)
		}

		public var storageClasses: ClusterScopedGenericKubernetesClient<storage.v1.StorageClass> {
			client.clusterScoped(for: storage.v1.StorageClass.self)
		}

		public var volumeAttachments: ClusterScopedGenericKubernetesClient<storage.v1.VolumeAttachment> {
			client.clusterScoped(for: storage.v1.VolumeAttachment.self)
		}
	}

	var storageV1: StorageV1API {
		StorageV1(self)
	}
}
