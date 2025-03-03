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

// MARK: - EventsV1API

public protocol EventsV1API: Sendable {

	var events: NamespacedGenericKubernetesClient<SwiftkubeModel.events.v1.Event> { get }
}

/// DSL for `events.k8s.io.v1` API Group
public extension KubernetesClient {

	final class EventsV1: EventsV1API {
		private let client: KubernetesClient

		internal init(_ client: KubernetesClient) {
			self.client = client
		}

		public var events: NamespacedGenericKubernetesClient<events.v1.Event> {
			client.namespaceScoped(for: SwiftkubeModel.events.v1.Event.self)
		}
	}

	var eventsV1: EventsV1API {
		EventsV1(self)
	}
}
