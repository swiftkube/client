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
@testable import SwiftkubeClient
import SwiftkubeModel
import XCTest

final class MergePatchTests: XCTestCase {

	let deployment = apps.v1.Deployment(
		metadata: meta.v1.ObjectMeta(name:"test", namespace: "ns"),
		spec: apps.v1.DeploymentSpec(
			replicas: 2,
			selector: sk.match(labels: ["app": "test"]),
			template: core.v1.PodTemplateSpec(metadata: sk.metadata(name: "podtest"), spec: sk.podSpec {
				$0.containers = [
					sk.container(name: "container1") {
						$0.image = "testing:latest"
					}
				]
			})
		),
		status: nil
	)

	func testEmptyMergePatch() {
		let config = core.v1.ConfigMap(metadata: meta.v1.ObjectMeta(), data: ["foo": "bar"])
		let mergePatch = config.mergePatch()

		XCTAssertNotNil(mergePatch)
		XCTAssertNil(mergePatch?.payload["metadata"])
		XCTAssertNotNil(mergePatch?.payload["data"])
	}

	func testEmptyPayloadInMergePatch() {
		let meta = meta.v1.ObjectMeta()
		XCTAssertNil(meta.mergePatch())
	}

	func testMergePatchExtension() {
		let mergePatch = deployment.mergePatch()
		let payload = mergePatch!.payload
		let dict = (payload as NSDictionary)

		XCTAssertEqual(Set(payload.keys), Set(arrayLiteral: "metadata", "spec"))

		XCTAssertEqual(dict.value(forKeyPath: "metadata.name") as! String, "test")
		XCTAssertEqual(dict.value(forKeyPath: "metadata.namespace") as! String, "ns")

		XCTAssertEqual(dict.value(forKeyPath: "spec.replicas") as! Int, 2)
		XCTAssertEqual(dict.value(forKeyPath: "spec.selector.matchLabels") as! [String: String], ["app": "test"])
		XCTAssertEqual(dict.value(forKeyPath: "spec.template.metadata.name") as! String, "podtest")

		let containers = dict.value(forKeyPath: "spec.template.spec.containers") as! [[String: Any]]
		XCTAssertTrue(containers.count == 1)
		XCTAssertEqual((containers[0] as NSDictionary).value(forKeyPath: "name") as! String, "container1")
		XCTAssertEqual((containers[0] as NSDictionary).value(forKeyPath: "image") as! String, "testing:latest")
	}

	func testMergePatchCodable() {
		let mergePatch = deployment.mergePatch()

		let encoded = try! JSONEncoder().encode(mergePatch)
		let decoded = try! JSONDecoder().decode(MergePatch.self, from: encoded)

		let payload = decoded.payload
		let dict = (payload as NSDictionary)

		XCTAssertEqual(Set(payload.keys), Set(arrayLiteral: "metadata", "spec"))

		XCTAssertEqual(dict.value(forKeyPath: "metadata.name") as! String, "test")
		XCTAssertEqual(dict.value(forKeyPath: "metadata.namespace") as! String, "ns")

		XCTAssertEqual(dict.value(forKeyPath: "spec.replicas") as! Int, 2)
		XCTAssertEqual(dict.value(forKeyPath: "spec.selector.matchLabels") as! [String: String], ["app": "test"])
		XCTAssertEqual(dict.value(forKeyPath: "spec.template.metadata.name") as! String, "podtest")

		let containers = dict.value(forKeyPath: "spec.template.spec.containers") as! [[String: Any]]
		XCTAssertTrue(containers.count == 1)
		XCTAssertEqual((containers[0] as NSDictionary).value(forKeyPath: "name") as! String, "container1")
		XCTAssertEqual((containers[0] as NSDictionary).value(forKeyPath: "image") as! String, "testing:latest")
	}
}
