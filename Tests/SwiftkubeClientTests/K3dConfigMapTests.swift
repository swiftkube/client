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

import SwiftkubeClient
import SwiftkubeModel
import XCTest

final class K3dConfigMapTests: K3dTestCase {

	override class func setUp() {
		super.setUp()

		// ensure clean state
		deleteNamespace("cm1")
		deleteNamespace("cm2")

		// create namespaces for tests
		createNamespace("cm1")
		createNamespace("cm2")
	}

	func testList() {
		[
			buildConfigMap("test1", data: ["app": "nginx", "env": "dev"]),
			buildConfigMap("test2", data: ["app": "nginx", "env": "qa"]),
			buildConfigMap("test3", data: ["app": "swiftkube", "env": "prod"])
		].forEach { configMap in
			_ = try? K3dTestCase.client.configMaps.create(inNamespace: .namespace("cm1"), configMap).wait()
		}

		let configMaps = try? K3dTestCase.client.configMaps.list(in: .namespace("cm1"))
			.map { $0.items.map(\.name) }
			.wait()

		assertEqual(configMaps, ["test1", "test2", "test3", "kube-root-ca.crt"])
	}

	func testCreate() {
		let configMap = try? K3dTestCase.client.configMaps.create(
			inNamespace: .namespace("cm2"),
			buildConfigMap("test", data: ["app": "nginx", "env": "dev"])
		)
		.wait()

		XCTAssertNotNil(configMap)
		XCTAssertEqual(configMap?.name, "test")
		XCTAssertEqual(configMap?.data, ["app": "nginx", "env": "dev"])
	}

	func testDelete() {
		_ = try? K3dTestCase.client.configMaps.create(
			inNamespace: .namespace("cm2"),
			buildConfigMap("deleteme", data: [:])
		)
		.flatMap { configMap in
			K3dTestCase.client.configMaps.delete(inNamespace: .namespace("cm2"), name: configMap.name!)
		}
		.wait()

		let deletedConfigMap = expectation(description: "Deleted ConfigMap")

		K3dTestCase.client.configMaps.get(in: .namespace("cm2"), name: "deleteme")
			.whenFailure{ error in
				if case let SwiftkubeClientError.requestError(status) = error, status.code == 404 {
					deletedConfigMap.fulfill()
				}
			}

		wait(for: [deletedConfigMap], timeout: 100)
	}

	private func buildConfigMap(_ name: String, data: [String: String]) -> core.v1.ConfigMap {
		return core.v1.ConfigMap(
			metadata: meta.v1.ObjectMeta(name: name),
			data: data
		)
	}
}
