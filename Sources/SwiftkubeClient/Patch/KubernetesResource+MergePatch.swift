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

public extension KubernetesResource {

	/// Constructs a new `MergePatch` instance from this `KubernetesResource`
	///
	/// The `MergePatch` will contain only non-empty non-null fields of this `KubernetesResource`.
	///
	/// - Returns: A `MergePatch` instance.
	func mergePatch() -> MergePatch? {
		var payload = [String: Any]()
		let mirror = Mirror(reflecting: self)

		for child in mirror.children {
			guard let propertyName = child.label else { continue }
			guard propertyName != "apiVersion", propertyName != "kind" else { continue }

			if let value = dynamicCast(child.value, to: KubernetesResource.self) {
				payload[propertyName] = value.mergePatch()?.payload
			} else if let value = dynamicCast(child.value, to: [KubernetesResource].self) {
				payload[propertyName] = value.compactMap { $0.mergePatch()?.payload }
			} else if case Optional<Any>.some(let value) = child.value {
				payload[propertyName] = value
			}
		}

		return MergePatch(payload: payload)
	}
}

private func dynamicCast<T>(_ value: Any, to _: T.Type) -> T? {
	let optional = value as Any?
	if let value = optional as? T {
		return value
	} else {
		return nil
	}
}
