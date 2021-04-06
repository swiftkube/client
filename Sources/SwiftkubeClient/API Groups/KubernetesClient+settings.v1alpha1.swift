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

// MARK: - SettingsV1Alpha1API

public protocol SettingsV1Alpha1API {

	var podPresets: NamespacedGenericKubernetesClient<settings.v1alpha1.PodPreset> { get }
}

/// DSL for `settings.v1alpha1` API Group
public extension KubernetesClient {

	class SettingsV1Alpha1: SettingsV1Alpha1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var podPresets: NamespacedGenericKubernetesClient<settings.v1alpha1.PodPreset> {
			client.namespaceScoped(for: settings.v1alpha1.PodPreset.self)
		}
	}

	var settingsV1Alpha1: SettingsV1Alpha1API {
		SettingsV1Alpha1(self)
	}
}
