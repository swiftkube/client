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

// MARK: - AuthorizationV1API

public protocol AuthorizationV1API {

	var selfSubjectRulesReviews: ClusterScopedGenericKubernetesClient<authorization.v1.SelfSubjectRulesReview> { get }

	var localSubjectAccessReviews: NamespacedGenericKubernetesClient<authorization.v1.LocalSubjectAccessReview> { get }

	var selfSubjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1.SelfSubjectAccessReview> { get }

	var subjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1.SubjectAccessReview> { get }
}

/// DSL for `authorization.v1` API Group
public extension KubernetesClient {

	class AuthorizationV1: AuthorizationV1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var selfSubjectRulesReviews: ClusterScopedGenericKubernetesClient<authorization.v1.SelfSubjectRulesReview> {
			client.clusterScoped(for: authorization.v1.SelfSubjectRulesReview.self)
		}

		public var localSubjectAccessReviews: NamespacedGenericKubernetesClient<authorization.v1.LocalSubjectAccessReview> {
			client.namespaceScoped(for: authorization.v1.LocalSubjectAccessReview.self)
		}

		public var selfSubjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1.SelfSubjectAccessReview> {
			client.clusterScoped(for: authorization.v1.SelfSubjectAccessReview.self)
		}

		public var subjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1.SubjectAccessReview> {
			client.clusterScoped(for: authorization.v1.SubjectAccessReview.self)
		}
	}

	var authorizationV1: AuthorizationV1API {
		AuthorizationV1(self)
	}
}
