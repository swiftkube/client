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

// MARK: - AdmissionRegistrationV1Alpha1API

public protocol AdmissionRegistrationV1Alpha1API {

	var validatingAdmissionPolicies: ClusterScopedGenericKubernetesClient<admissionregistration.v1alpha1.ValidatingAdmissionPolicy> { get }
	var validatingAdmissionPolicyBindings: ClusterScopedGenericKubernetesClient<admissionregistration.v1alpha1.ValidatingAdmissionPolicyBinding> { get }
}

/// DSL for `admissionregistration.k8s.io.v1alpha1` API Group
public extension KubernetesClient {

	class AdmissionRegistrationV1Alpha1: AdmissionRegistrationV1Alpha1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var validatingAdmissionPolicies: ClusterScopedGenericKubernetesClient<admissionregistration.v1alpha1.ValidatingAdmissionPolicy> {
			client.clusterScoped(for: admissionregistration.v1alpha1.ValidatingAdmissionPolicy.self)
		}

		public var validatingAdmissionPolicyBindings: ClusterScopedGenericKubernetesClient<admissionregistration.v1alpha1.ValidatingAdmissionPolicyBinding> {
			client.clusterScoped(for: admissionregistration.v1alpha1.ValidatingAdmissionPolicyBinding.self)
		}
	}

	var admissionRegistrationV1Alpha1: AdmissionRegistrationV1Alpha1API {
		AdmissionRegistrationV1Alpha1(self)
	}
}
