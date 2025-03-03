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

// MARK: - AuthenticationV1Beta1API

public protocol AuthenticationV1Beta1API: Sendable {

	var selfSubjectReviews: ClusterScopedGenericKubernetesClient<authentication.v1beta1.SelfSubjectReview> { get }
}

/// DSL for `authentication.k8s.io.v1beta1` API Group
public extension KubernetesClient {

	final class AuthenticationV1Beta1: AuthenticationV1Beta1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var selfSubjectReviews: ClusterScopedGenericKubernetesClient<authentication.v1beta1.SelfSubjectReview> {
			client.clusterScoped(for: authentication.v1beta1.SelfSubjectReview.self)
		}
	}

	var authenticationV1Beta1: AuthenticationV1Beta1API {
		AuthenticationV1Beta1(self)
	}
}
