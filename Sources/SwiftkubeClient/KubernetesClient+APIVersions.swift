//
// Copyright 2020 Iskandar Abudiab (iabudiab.dev)
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

public protocol AppsV1API {
	var daemonSets: ClusterScopedGenericKubernetesClient<apps.v1.DaemonSet> { get }
	var deployments: NamespacedGenericKubernetesClient<apps.v1.Deployment> { get }
	var statefulSets: NamespacedGenericKubernetesClient<apps.v1.StatefulSet> { get }
}

public extension KubernetesClient {

	class AppsV1: AppsV1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var daemonSets: ClusterScopedGenericKubernetesClient<apps.v1.DaemonSet> {
			client.clusterScoped(for: apps.v1.DaemonSet.self)
		}

		public var deployments: NamespacedGenericKubernetesClient<apps.v1.Deployment> {
			client.namespaceScoped(for: apps.v1.Deployment.self)
		}

		public var statefulSets: NamespacedGenericKubernetesClient<apps.v1.StatefulSet> {
			client.namespaceScoped(for: apps.v1.StatefulSet.self)
		}
	}

	var appsV1: AppsV1API { AppsV1(self) }
}

public protocol NetworkingV1Beta1API {

	var ingresses: NamespacedGenericKubernetesClient<networking.v1beta1.Ingress> { get }
}

public extension KubernetesClient {

	class NetworkingV1Beta1: NetworkingV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var ingresses: NamespacedGenericKubernetesClient<networking.v1beta1.Ingress> {
			client.namespaceScoped(for: networking.v1beta1.Ingress.self)
		}
	}

	var networkingV1Beta1: NetworkingV1Beta1API { NetworkingV1Beta1(self) }
}

public protocol RBACV1API {

	var clusterRoles: ClusterScopedGenericKubernetesClient<rbac.v1.ClusterRole> { get }
	var clusterRoleBindings: ClusterScopedGenericKubernetesClient<rbac.v1.ClusterRoleBinding> { get }
	var roles: NamespacedGenericKubernetesClient<rbac.v1.Role> { get }
	var roleBindings: NamespacedGenericKubernetesClient<rbac.v1.RoleBinding> { get }
}

public extension KubernetesClient {

	class RBACV1: RBACV1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var clusterRoles: ClusterScopedGenericKubernetesClient<rbac.v1.ClusterRole> {
			client.clusterScoped(for: rbac.v1.ClusterRole.self)
		}

		public var clusterRoleBindings: ClusterScopedGenericKubernetesClient<rbac.v1.ClusterRoleBinding> {
			client.clusterScoped(for: rbac.v1.ClusterRoleBinding.self)
		}

		public var roles: NamespacedGenericKubernetesClient<rbac.v1.Role> {
			client.namespaceScoped(for: rbac.v1.Role.self)
		}

		public var roleBindings: NamespacedGenericKubernetesClient<rbac.v1.RoleBinding> {
			client.namespaceScoped(for: rbac.v1.RoleBinding.self)
		}
	}

	var rbacV1: RBACV1API { RBACV1(self) }
}
