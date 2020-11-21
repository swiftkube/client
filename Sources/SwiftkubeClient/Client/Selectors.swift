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

	public func namespaceName() -> String {
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

public enum ListOption {
	case limit(Int)
	case labelSelector([String: String])
	case fieldSelector([String: String])
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
		case .labelSelector(let labels):
			return labels.map { key, value in "\(key)=\(value)" }.joined(separator: ",")
		case .fieldSelector(let fields):
			return fields.map { key, value in "\(key)=\(value)" }.joined(separator: ",")
		case .resourceVersion(let version):
			return version
		case .timeoutSeconds(let timeout):
			return timeout.description
		case .pretty(let pretty):
			return pretty.description
		}
	}
}
