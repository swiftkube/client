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

// MARK: - BatchV1API

public protocol BatchV1API {

	var jobs: NamespacedGenericKubernetesClient<batch.v1.Job> { get }
}

/// DSL for `batch.v1` API Group
public extension KubernetesClient {

	class BatchV1: BatchV1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var jobs: NamespacedGenericKubernetesClient<batch.v1.Job> {
			client.namespaceScoped(for: batch.v1.Job.self)
		}
	}

	var batchV1: BatchV1API {
		BatchV1(self)
	}
}
