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

// MARK: - AuthenticationV1API

public protocol AuthenticationV1API {

	var selfSubjectReviews: ClusterScopedGenericKubernetesClient<authentication.v1.SelfSubjectReview> { get }
	var tokenRequests: NamespacedGenericKubernetesClient<authentication.v1.TokenRequest> { get }
	var tokenReviews: ClusterScopedGenericKubernetesClient<authentication.v1.TokenReview> { get }
}

/// DSL for `authentication.k8s.io.v1` API Group
public extension KubernetesClient {

	class AuthenticationV1: AuthenticationV1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var selfSubjectReviews: ClusterScopedGenericKubernetesClient<authentication.v1.SelfSubjectReview> {
			client.clusterScoped(for: authentication.v1.SelfSubjectReview.self)
		}

		public var tokenRequests: NamespacedGenericKubernetesClient<authentication.v1.TokenRequest> {
			client.namespaceScoped(for: authentication.v1.TokenRequest.self)
		}

		public var tokenReviews: ClusterScopedGenericKubernetesClient<authentication.v1.TokenReview> {
			client.clusterScoped(for: authentication.v1.TokenReview.self)
		}
	}

	var authenticationV1: AuthenticationV1API {
		AuthenticationV1(self)
	}
}
