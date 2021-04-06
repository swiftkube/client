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

// MARK: - EventsV1Beta1API

public protocol EventsV1Beta1API {

	var events: NamespacedGenericKubernetesClient<events.v1beta1.Event> { get }
}

/// DSL for `events.v1beta1` API Group
public extension KubernetesClient {

	class EventsV1Beta1: EventsV1Beta1API {
		private var client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var events: NamespacedGenericKubernetesClient<events.v1beta1.Event> {
			client.namespaceScoped(for: SwiftkubeModel.events.v1beta1.Event.self)
		}
	}

	var eventsV1Beta1: EventsV1Beta1API {
		EventsV1Beta1(self)
	}
}
