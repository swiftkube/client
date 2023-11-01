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

internal let ObjectMetaNamespaceIndexFunction: IndexFuntion<Any> = { item in
	switch item {
	case let metadataHaiving as any MetadataHavingResource:
		guard let namespace = metadataHaiving.metadata?.namespace else {
			return []
		}
		return [namespace]

	case let dict as Dictionary<String, Any>:
		guard
			let metadata = dict["metadata"] as? Dictionary<String, Any>,
			let namespace = metadata["namespace"] as? String
		else {
			return []
		}
		return [namespace]

	default:
		throw CacheError.invalidObject
	}
}

internal let ObjectMetaNamespaceKeyFunction: KeyFuntion<Any> = { item in
	switch item {
	case let metadataHaiving as any MetadataHavingResource:
		guard
			let namespace = metadataHaiving.metadata?.namespace,
			let name = metadataHaiving.metadata?.name
		else {
			throw CacheError.invalidObject
		}
		return "\(namespace)/\(name)"

	case let metadata as meta.v1.ObjectMeta:
		guard
			let namespace = metadata.namespace,
			let name = metadata.name
		else {
			throw CacheError.invalidObject
		}
		return "\(namespace)/\(name)"

	case let dict as Dictionary<String, Any>:
		guard
			let metadata = dict["metadata"] as? Dictionary<String, Any>,
			let namespace = metadata["namespace"] as? String,
			let name = metadata["name"] as? String
		else {
			throw CacheError.invalidObject
		}
		return "\(namespace)/\(name)"

	case let string as String:
		return string

	default:
		throw CacheError.invalidObject
	}
}
