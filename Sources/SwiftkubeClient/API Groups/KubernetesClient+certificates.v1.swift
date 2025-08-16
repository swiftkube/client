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

// MARK: - CertificatesV1API

public protocol CertificatesV1API: Sendable {

	var certificateSigningRequests: ClusterScopedGenericKubernetesClient<certificates.v1.CertificateSigningRequest> { get }
}

/// DSL for `certificates.k8s.io.v1` API Group
public extension KubernetesClient {

	final class CertificatesV1: CertificatesV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var certificateSigningRequests: ClusterScopedGenericKubernetesClient<certificates.v1.CertificateSigningRequest> {
			client.clusterScoped(for: certificates.v1.CertificateSigningRequest.self)
		}
	}

	var certificatesV1: CertificatesV1API {
		CertificatesV1(self)
	}
}
