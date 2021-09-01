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
import Yams

// MARK: - MergePatch

/// A JSON Merge Patch object for patching Kubernetes resources.
///
/// A JSON Merge Patch document is analogous to a diff file, i.e. it holds only the nodes that should changed.
/// That also means, that in order to add, modify or remove array elements, the whole array should be specified.
///
/// Example: given a deployment resource:
///
/// ```yaml
/// apiVersion: apps/v1
/// kind: Deployment
/// metadata:
///   name: patch-demo
/// spec:
///   replicas: 2
///   selector:
///     matchLabels:
///       app: nginx
///   template:
///     metadata:
///       labels:
///         app: nginx
///     spec:
///       containers:
///       - name: patch-1
///         image: nginx
///       tolerations:
/// ```
/// in order to change the replica count and the container image the following merge patch can be used:
///
/// ```yaml
/// spec:
///   replicas: 3
///   template:
///     spec:
///       containers:
///       - name: patch-2
///         image: nginx-patched
/// ```
///
/// - Attention
/// A `MergePatch` instance cannot be initialised directly, but rather constructed from a
/// `KubernetesResource`. So the previous patch can be constrcuted from a `Deployment` instance like this:
///
/// ```swift
/// let deployment = apps.v1.Deployment(
///   spec: apps.v1.DeploymentSpec(
///     replicas: 3,
///     selector: meta.v1.LabelSelector(),
///     template: core.v1.PodTemplateSpec(
///       spec: core.v1.PodSpec(
///         containers: [
///           core.v1.Container(
///             image: "nignx-patched",
///             name: "patch-1"
///           )
///         ]
///       )
///     )
///   )
/// )
///
/// let patch = deployment.mergePatch()
/// ```
/// - Remark
/// The deployment in the example above has its `selector` field defined because it is non-nullable
/// and has to be provided in the initialiser. However, the created `MergePatch` will contain only
/// non-empty non-null fields of the deployment object.
///
public struct MergePatch {

	internal let payload: [String: Any]

	/// Internal constructor for initialising a `MergePatch` with a payload dictionary.
	///
	/// - Parameter payload: The payload for this `MergePatch`
	internal init?(payload: [String: Any]) {
		guard !payload.isEmpty else {
			return nil
		}
		self.payload = payload
	}

	/// Loads a `MergePatch` from the given `URL` containing a patch in YAML form.
	///
	/// - Parameter url: The URL from which a `MergePatch` should be loaded
	/// - Throws: Decoding errors if the YAML cannot be loaded from the given URL
	/// - Returns: A `MergePatch` instance
	public static func load(contentsOf url: URL) throws -> Self {
		let data = try Data(contentsOf: url)
		let decoder = YAMLDecoder()
		return try decoder.decode(Self.self, from: data)
	}
}

// MARK: Codable

extension MergePatch: Codable {

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: JSONCodingKeys.self)
		self.payload = try container.decode([String: Any].self)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: JSONCodingKeys.self)
		try container.encode(payload)
	}
}
