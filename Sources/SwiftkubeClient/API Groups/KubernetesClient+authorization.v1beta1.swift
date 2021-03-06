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

// MARK: - AuthorizationV1Beta1API

public protocol AuthorizationV1Beta1API {

	var selfSubjectRulesReviews: ClusterScopedGenericKubernetesClient<authorization.v1beta1.SelfSubjectRulesReview> { get }

	var selfSubjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1beta1.SelfSubjectAccessReview> { get }

	var subjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1beta1.SubjectAccessReview> { get }

	var localSubjectAccessReviews: NamespacedGenericKubernetesClient<authorization.v1beta1.LocalSubjectAccessReview> { get }
}

/// DSL for `authorization.v1beta1` API Group
public extension KubernetesClient {

	class AuthorizationV1Beta1: AuthorizationV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var selfSubjectRulesReviews: ClusterScopedGenericKubernetesClient<authorization.v1beta1.SelfSubjectRulesReview> {
			client.clusterScoped(for: authorization.v1beta1.SelfSubjectRulesReview.self)
		}

		public var selfSubjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1beta1.SelfSubjectAccessReview> {
			client.clusterScoped(for: authorization.v1beta1.SelfSubjectAccessReview.self)
		}

		public var subjectAccessReviews: ClusterScopedGenericKubernetesClient<authorization.v1beta1.SubjectAccessReview> {
			client.clusterScoped(for: authorization.v1beta1.SubjectAccessReview.self)
		}

		public var localSubjectAccessReviews: NamespacedGenericKubernetesClient<authorization.v1beta1.LocalSubjectAccessReview> {
			client.namespaceScoped(for: authorization.v1beta1.LocalSubjectAccessReview.self)
		}
	}

	var authorizationV1Beta1: AuthorizationV1Beta1API {
		AuthorizationV1Beta1(self)
	}
}
