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

/// Options for `List` API calls.
public enum ListOption {
	/// Limit is a maximum number of responses to return for a list call.
	///
	/// If more items exist, the server will set the `continue` field on the list metadata to a value that can be used with the same initial
	/// query to retrieve the next set of results. Setting a limit may return fewer than the requested amount of items (up to zero items) in the event
	/// all requested objects are filtered out and clients should only use the presence of the continue field to determine whether more results
	///  are available. Servers may choose not to support the limit argument and will return all of the available results.
	///
	///  If limit is specified and the continue field is empty, clients may assume that no more results are available. This field is not
	///  supported if watch is true. The server guarantees that the objects returned when using continue will be identical to issuing a single
	///  list call without a limit - that is, no objects created, modified, or deleted after the first request is issued will be included in any subsequent
	///  continued requests. This is sometimes referred to as a consistent snapshot, and ensures that a client that is using limit to receive smaller
	///  chunks of a very large result can ensure they see all possible objects. If objects are updated during a chunked list the version of the object
	///  that was present at the time the first list result was calculated is returned.
	case limit(Int)
	/// A selector to restrict the list of returned objects by their labels.
	///
	/// Defaults to everything.
	case labelSelector(LabelSelectorRequirement)
	/// A selector to restrict the list of returned objects by their fields.
	///
	/// Defaults to everything.
	case fieldSelector(FieldSelectorRequirement)
	/// resourceVersion sets a constraint on what resource versions a request may be served from.
	/// See https://kubernetes.io/docs/reference/using-api/api-concepts/#resource-versions for details.
	///
	/// Defaults to unset
	case resourceVersion(String)
	/// Timeout for the list/watch call. This limits the duration of the call, regardless of any activity or inactivity.
	case timeoutSeconds(Int)
	/// If 'true', then the output is pretty printed.
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

// MARK: - ReadOption

/// Options for `Read` API calls
public enum ReadOption {
	/// If 'true', then the output is pretty printed.
	case pretty(Bool)
	/// Should the export be exact. Exact export maintains cluster-specific fields like 'Namespace'.
	///
	/// Deprecated. Planned for removal in 1.18.
	case export(Bool)
	/// Should this value be exported. Export strips fields that a user can not specify.
	///
	/// Deprecated. Planned for removal in 1.18.
	case exact(Bool)

	public var name: String {
		switch self {
		case .pretty:
			return "pretty"
		case .export:
			return "export"
		case .exact:
			return "exact"
		}
	}

	public var value: String {
		switch self {
		case let .pretty(pretty):
			return pretty.description
		case let .export(export):
			return export.description
		case let .exact(exact):
			return exact.description
		}
	}
}

// MARK: - Collection Extensions

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

internal extension Array where Element == ListOption {
	func collectQueryItems() -> [URLQueryItem] {
		Dictionary(grouping: self, by: \.name)
			.map {
				let value = $0.value.map(\.value).joined(separator: ",")
				return URLQueryItem(name: $0.key, value: value)
			}
	}
}

internal extension Array where Element == ReadOption {
	func collectQueryItems() -> [URLQueryItem] {
		Dictionary(grouping: self, by: \.name)
			.map {
				let value = $0.value.map(\.value).joined(separator: ",")
				return URLQueryItem(name: $0.key, value: value)
			}
	}
}
