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

// MARK: - AdmissionRegistrationV1Beta1API

public protocol AdmissionRegistrationV1Beta1API: Sendable {

	var validatingAdmissionPolicies: ClusterScopedGenericKubernetesClient<admissionregistration.v1beta1.ValidatingAdmissionPolicy> { get }
	var validatingAdmissionPolicyBindings: ClusterScopedGenericKubernetesClient<admissionregistration.v1beta1.ValidatingAdmissionPolicyBinding> { get }
}

/// DSL for `admissionregistration.k8s.io.v1beta1` API Group
public extension KubernetesClient {

	final class AdmissionRegistrationV1Beta1: AdmissionRegistrationV1Beta1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var validatingAdmissionPolicies: ClusterScopedGenericKubernetesClient<admissionregistration.v1beta1.ValidatingAdmissionPolicy> {
			client.clusterScoped(for: admissionregistration.v1beta1.ValidatingAdmissionPolicy.self)
		}

		public var validatingAdmissionPolicyBindings: ClusterScopedGenericKubernetesClient<admissionregistration.v1beta1.ValidatingAdmissionPolicyBinding> {
			client.clusterScoped(for: admissionregistration.v1beta1.ValidatingAdmissionPolicyBinding.self)
		}
	}

	var admissionRegistrationV1Beta1: AdmissionRegistrationV1Beta1API {
		AdmissionRegistrationV1Beta1(self)
	}
}
