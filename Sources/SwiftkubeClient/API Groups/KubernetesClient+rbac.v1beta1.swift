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

// MARK: - RBACV1Beta1API

public protocol RBACV1Beta1API {

	var clusterRoles: ClusterScopedGenericKubernetesClient<rbac.v1beta1.ClusterRole> { get }
	var clusterRoleBindings: ClusterScopedGenericKubernetesClient<rbac.v1beta1.ClusterRoleBinding> { get }
	var roles: NamespacedGenericKubernetesClient<rbac.v1beta1.Role> { get }
	var roleBindings: NamespacedGenericKubernetesClient<rbac.v1beta1.RoleBinding> { get }
}

/// DSL for `rbac.authorization.k8s.io.v1beta1` API Group
public extension KubernetesClient {

	class RBACV1Beta1: RBACV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var clusterRoles: ClusterScopedGenericKubernetesClient<rbac.v1beta1.ClusterRole> {
			client.clusterScoped(for: rbac.v1beta1.ClusterRole.self)
		}

		public var clusterRoleBindings: ClusterScopedGenericKubernetesClient<rbac.v1beta1.ClusterRoleBinding> {
			client.clusterScoped(for: rbac.v1beta1.ClusterRoleBinding.self)
		}

		public var roles: NamespacedGenericKubernetesClient<rbac.v1beta1.Role> {
			client.namespaceScoped(for: rbac.v1beta1.Role.self)
		}

		public var roleBindings: NamespacedGenericKubernetesClient<rbac.v1beta1.RoleBinding> {
			client.namespaceScoped(for: rbac.v1beta1.RoleBinding.self)
		}
	}

	var rbacV1Beta1: RBACV1Beta1API {
		RBACV1Beta1(self)
	}
}
