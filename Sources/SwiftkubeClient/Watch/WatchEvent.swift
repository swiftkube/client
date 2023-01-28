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

// MARK: - EventType

/// Possible kubernetes event types.
public enum EventType: String, RawRepresentable, Equatable {
	case added = "ADDED"
	case modified = "MODIFIED"
	case deleted = "DELETED"
	case error = "ERROR"
}

// MARK: - WatchEvent

/// Represents a Kubernetes event with a type and the resource it references.
public struct WatchEvent<Resource: KubernetesAPIResource> {
	public let type: EventType
	public let resource: Resource
}
