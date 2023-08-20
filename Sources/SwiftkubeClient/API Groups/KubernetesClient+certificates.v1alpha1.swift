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

// MARK: - CertificatesV1Alpha1API

public protocol CertificatesV1Alpha1API {

	var clusterTrusubundles: ClusterScopedGenericKubernetesClient<certificates.v1alpha1.ClusterTrustBundle> { get }
}

/// DSL for `certificates.k8s.io.v1alpha1` API Group
public extension KubernetesClient {

	class CertificatesV1Alpha1: CertificatesV1Alpha1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var clusterTrusubundles: ClusterScopedGenericKubernetesClient<certificates.v1alpha1.ClusterTrustBundle> {
			client.clusterScoped(for: certificates.v1alpha1.ClusterTrustBundle.self)
		}
	}

	var certificatesV1Alpha1: CertificatesV1Alpha1API {
		CertificatesV1Alpha1(self)
	}
}
