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

// MARK: - StorageVersionMigrationV1Alpha1API

public protocol StorageVersionMigrationV1Alpha1API: Sendable {

	var storageVersionMigrations: ClusterScopedGenericKubernetesClient<storagemigration.v1alpha1.StorageVersionMigration> { get }
}

/// DSL for `storagemigration.k8s.io.v1alpha1` API Group
public extension KubernetesClient {

	final class StorageVersionMigrationV1Alpha1: StorageVersionMigrationV1Alpha1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var storageVersionMigrations: ClusterScopedGenericKubernetesClient<storagemigration.v1alpha1.StorageVersionMigration> {
			client.clusterScoped(for: storagemigration.v1alpha1.StorageVersionMigration.self)
		}
	}

	var storageVersionMigrationV1Alpha1: StorageVersionMigrationV1Alpha1API {
		StorageVersionMigrationV1Alpha1(self)
	}
}
