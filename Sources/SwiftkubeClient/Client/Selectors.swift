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

import AsyncHTTPClient
import Foundation
import Logging
import NIO
import NIOHTTP1
import SwiftkubeModel

// MARK: - NamespaceSelector

/// A namespace selector enumeration for use in namespaced client requests.
public enum NamespaceSelector: Hashable, Sendable {
	/// Selects a namespace by name.
	case namespace(String)
	/// Selects the `default` namespace.
	case `default`
	/// Selects the `kube-public` namespace.
	case `public`
	/// Selects the `kube-system` namespace.
	case system
	/// Selects the `kube-node-lease` namespace.
	case nodeLease
	/// Selects all namespaces.
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

/// Represents requirements fot label selectors, for example in ``ListOption/labelSelector(_:)``.
///
/// The kubernetes API supports two types of selectors: equality-based and set-based:
/// - Equality- or inequality-based requirements allow filtering by label keys and values.
/// - Set-based label requirements allow filtering keys according to a set of values.
///
/// A label selector can be made of multiple requirements. In the case of multiple requirements, all must be satisfied.
public enum LabelSelectorRequirement: Hashable, Sendable {
	/// Filters by matching label keys and values.
	case eq([String: String])
	/// Filters by non-matching label keys and values.
	case neq([String: String])
	/// Label values for the given key are contained in the given set.
	case `in`([String: [String]])
	/// Label values for the given key are not contained in the given set.
	case notIn([String: [String]])
	/// A label must exist.
	case exists([String])
	/// A label must not exist.
	case doesNotExist([String])

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
		case let .doesNotExist(labels):
			return labels.joined(separator: ",")
		}
	}
}

// MARK: - FieldSelectorRequirement

/// Represents requirements fot label selectors, for example in ``ListOption/fieldSelector(_:)``.
///
/// Field selectors let you select Kubernetes resources based on the value of one or more resource fields.
public enum FieldSelectorRequirement: Hashable, Sendable {
	/// Filters by matching field keys and values.
	case eq([String: String])
	/// Filters by non-matching field keys and values.
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
public enum ListOption: Hashable, Sendable {
	/// The continue option should be set when retrieving more results from the server.
	///
	/// Since this value is server defined, clients may only use the continue value from a previous query result with identical query parameters
	/// (except for the value of continue) and the server may reject a continue value it does not recognize. If the specified continue value is
	/// no longer valid whether due to expiration (generally five to fifteen minutes) or a configuration change on the server, the server will
	/// respond with a 410 ResourceExpired error together with a continue token. If the client needs a consistent list, it must restart their
	/// list without the continue field.
	///
	/// Otherwise, the client may send another list request with the token received with the 410 error, the server will respond with a list
	/// starting from the next key, but from the latest snapshot, which is inconsistent from the previous list results - objects that are
	/// created, modified, or deleted after the first list request will be included in the response, as long as their keys are after the "next key".
	///
	/// This field is not supported when watch is true. Clients may start a watch from the last
	/// resourceVersion value returned by the server and not miss any modifications.
	case `continue`(String)
	/// A selector to restrict the list of returned objects by their fields.
	///
	/// Defaults to everything.
	case fieldSelector(FieldSelectorRequirement)
	/// A selector to restrict the list of returned objects by their labels.
	///
	/// Defaults to everything.
	case labelSelector(LabelSelectorRequirement)
	/// Limit is a maximum number of responses to return for a list call.
	///
	/// If more items exist, the server will set the `continue` field on the list metadata to a value that can be used with the same initial
	/// query to retrieve the next set of results. Setting a limit may return fewer than the requested amount of items (up to zero items) in the event
	/// all requested objects are filtered out and clients should only use the presence of the continue field to determine whether more results
	/// are available. Servers may choose not to support the limit argument and will return all of the available results.
	///
	///  If limit is specified and the continue field is empty, clients may assume that no more results are available. This field is not
	///  supported if watch is true. The server guarantees that the objects returned when using continue will be identical to issuing a single
	///  list call without a limit - that is, no objects created, modified, or deleted after the first request is issued will be included in any subsequent
	///  continued requests. This is sometimes referred to as a consistent snapshot, and ensures that a client that is using limit to receive smaller
	///  chunks of a very large result can ensure they see all possible objects. If objects are updated during a chunked list the version of the object
	///  that was present at the time the first list result was calculated is returned.
	case limit(Int)
	/// If 'true', then the output is pretty printed.
	case pretty(Bool)
	/// resourceVersion sets a constraint on what resource versions a request may be served from.
	/// See https://kubernetes.io/docs/reference/using-api/api-concepts/#resource-versions for details.
	///
	/// Defaults to unset
	case resourceVersion(String)
	/// Timeout for the list/watch call. This limits the duration of the call, regardless of any activity or inactivity.
	case timeoutSeconds(Int)

	public var name: String {
		switch self {
		case .continue:
			return "continue"
		case .fieldSelector:
			return "fieldSelector"
		case .limit:
			return "limit"
		case .labelSelector:
			return "labelSelector"
		case .pretty:
			return "pretty"
		case .resourceVersion:
			return "resourceVersion"
		case .timeoutSeconds:
			return "timeoutSeconds"
		}
	}

	public var value: String {
		switch self {
		case let .continue(token):
			return token
		case let .fieldSelector(requirement):
			return requirement.value
		case let .limit(limit):
			return limit.description
		case let .labelSelector(requirement):
			return requirement.value
		case let .pretty(pretty):
			return pretty.description
		case let .resourceVersion(version):
			return version
		case let .timeoutSeconds(timeout):
			return timeout.description
		}
	}
}

// MARK: - ReadOption

/// Options for `Read` API calls
public enum ReadOption: Hashable, Sendable {
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
