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

import AsyncHTTPClient
import Foundation
import Logging
import NIO
import NIOHTTP1
import SwiftkubeModel

// MARK: - NamespaceSelector

public enum NamespaceSelector {
	case namespace(String)
	case `default`
	case `public`
	case system
	case nodeLease
	case allNamespaces

	internal func namespaceName() -> String {
		switch self {
		case let .namespace(name):
			return name
		case .default:
			return "default"
		case .public:
			return "kube-public"
		case .system:
			return "kube-system"
		case .nodeLease:
			return "kube-node-lease"
		case .allNamespaces:
			return ""
		}
	}
}

internal extension Dictionary where Key == String, Value == String {
	func asQueryParam(joiner op: String) -> String {
		map { key, value in "\(key)\(op)\(value)" }
			.joined(separator: ",")
	}
}

internal extension Dictionary where Key == String, Value == [String] {
	func asQueryParam(joiner op: String) -> String {
		map { key, value in
			let joinedValue = value.joined(separator: ",")
			return "\(key) \(op) (\(joinedValue))"
		}
		.joined(separator: ",")
	}
}

// MARK: - LabelSelectorRequirement

public enum LabelSelectorRequirement {
	case eq([String: String])
	case neq([String: String])
	case `in`([String: [String]])
	case notIn([String: [String]])
	case exists([String])

	internal var value: String {
		switch self {
		case let .eq(labels):
			return labels.asQueryParam(joiner: "=")
		case let .neq(labels):
			return labels.asQueryParam(joiner: "!=")
		case let .in(labels):
			return labels.asQueryParam(joiner: "in")
		case let .notIn(labels):
			return labels.asQueryParam(joiner: "notin")
		case let .exists(labels):
			return labels.joined(separator: ",")
		}
	}
}

// MARK: - FieldSelectorRequirement

public enum FieldSelectorRequirement {
	case eq([String: String])
	case neq([String: String])

	internal var value: String {
		switch self {
		case let .eq(labels):
			return labels.asQueryParam(joiner: "=")
		case let .neq(labels):
			return labels.asQueryParam(joiner: "!=")
		}
	}
}

// MARK: - ListOption

public enum ListOption {
	case limit(Int)
	case labelSelector(LabelSelectorRequirement)
	case fieldSelector(FieldSelectorRequirement)
	case resourceVersion(String)
	case timeoutSeconds(Int)
	case pretty(Bool)

	public var name: String {
		switch self {
		case .limit:
			return "limit"
		case .labelSelector:
			return "labelSelector"
		case .fieldSelector:
			return "fieldSelector"
		case .resourceVersion:
			return "resourceVersion"
		case .timeoutSeconds:
			return "timeoutSeconds"
		case .pretty:
			return "pretty"
		}
	}

	public var value: String {
		switch self {
		case let .limit(limit):
			return limit.description
		case let .labelSelector(requirement):
			return requirement.value
		case let .fieldSelector(requirement):
			return requirement.value
		case let .resourceVersion(version):
			return version
		case let .timeoutSeconds(timeout):
			return timeout.description
		case let .pretty(pretty):
			return pretty.description
		}
	}
}
