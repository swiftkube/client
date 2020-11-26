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

import AsyncHTTPClient
import Foundation
import Logging
import NIO
import NIOHTTP1
import SwiftkubeModel

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
		self.map { key, value in "\(key)\(op)\(value)"}
			.joined(separator: ",")
	}
}

internal extension Dictionary where Key == String, Value == [String] {

	func asQueryParam(joiner op: String) -> String {
		self.map { key, value in
			let joinedValue = value.joined(separator: ",")
			return "\(key) \(op) (\(joinedValue))"
		}
		.joined(separator: ",")
	}
}

public enum LabelSelectorRequirement {
	case eq([String: String])
	case neq([String: String])
	case `in`([String: [String]])
	case notIn([String: [String]])
	case exists([String])

	internal var value: String {
		switch self {
		case .eq(let labels):
			return labels.asQueryParam(joiner: "=")
		case .neq(let labels):
			return labels.asQueryParam(joiner: "!=")
		case .in(let labels):
			return labels.asQueryParam(joiner: "in")
		case .notIn(let labels):
			return labels.asQueryParam(joiner: "notin")
		case .exists(let labels):
			return labels.joined(separator: ",")
		}
	}
}

public enum FieldSelectorRequirement {
	case eq([String: String])
	case neq([String: String])

	internal var value: String {
		switch self {
		case .eq(let labels):
			return labels.asQueryParam(joiner: "=")
		case .neq(let labels):
			return labels.asQueryParam(joiner: "!=")
		}
	}
}

public enum ListOption {
	case limit(Int)
	case labelSelector(LabelSelectorRequirement)
	case fieldSelector(FieldSelectorRequirement)
	case resourceVersion(String)
	case timeoutSeconds(Int)
	case pretty(Bool)

	public var name: String {
		switch self {
		case .limit(_):
			return "limit"
		case .labelSelector:
			return "labelSelector"
		case .fieldSelector:
			return "fieldSelector"
		case .resourceVersion(_):
			return "resourceVersion"
		case .timeoutSeconds(_):
			return "timeoutSeconds"
		case .pretty(_):
			return "pretty"
		}
	}

	public var value: String {
		switch self {
		case .limit(let limit):
			return limit.description
		case .labelSelector(let requirement):
			return requirement.value
		case .fieldSelector(let requirement):
			return requirement.value
		case .resourceVersion(let version):
			return version
		case .timeoutSeconds(let timeout):
			return timeout.description
		case .pretty(let pretty):
			return pretty.description
		}
	}
}
