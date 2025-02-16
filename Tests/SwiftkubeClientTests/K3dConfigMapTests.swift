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

import Logging
import SwiftkubeClient
import SwiftkubeModel
import XCTest

final class K3dConfigMapTests: K3dTestCase {

	override class func setUp() {
		super.setUp()

		// ensure clean state
		deleteNamespace("cm1")
		deleteNamespace("cm2")
		deleteNamespace("cm3")

		// create namespaces for tests
		createNamespace("cm1")
		createNamespace("cm2")
		createNamespace("cm3")
	}

	func testList() async {
		for configMap in [
			buildConfigMap("test1", data: ["app": "nginx", "env": "dev"]),
			buildConfigMap("test2", data: ["app": "nginx", "env": "qa"]),
			buildConfigMap("test3", data: ["app": "swiftkube", "env": "prod"])
		] {
			try? _ = await K3dTestCase.client.configMaps.create(inNamespace: .namespace("cm1"), configMap)
		}

		let configMaps = try? await K3dTestCase.client.configMaps.list(in: .namespace("cm1"))
			.map {
				$0.name
			}

		assertEqual(configMaps, ["test1", "test2", "test3", "kube-root-ca.crt"])
	}

	func testCreate() async {
		let configMap = try? await K3dTestCase.client.configMaps.create(
			inNamespace: .namespace("cm2"),
			buildConfigMap("test", data: ["app": "nginx", "env": "dev"])
		)

		XCTAssertNotNil(configMap)
		XCTAssertEqual(configMap?.name, "test")
		XCTAssertEqual(configMap?.data, ["app": "nginx", "env": "dev"])
	}

	func testDelete() async {
		let configMap = try? await K3dTestCase.client.configMaps.create(
			inNamespace: .namespace("cm2"),
			buildConfigMap("deleteme", data: [:])
		)

		XCTAssertNotNil(configMap)

		let _ = try? await K3dTestCase.client.configMaps.delete(inNamespace: .namespace("cm2"), name: configMap!.name!)

		let deletedConfigMap = expectation(description: "Deleted ConfigMap")

		do {
			let _ = try await K3dTestCase.client.configMaps.get(in: .namespace("cm2"), name: "deleteme")
		} catch let error {
			guard case let SwiftkubeClientError.statusError(status) = error, status.code == 404 else {
				return
			}

			deletedConfigMap.fulfill()
		}

		await fulfillment(of: [deletedConfigMap], timeout: 30)
	}

	func testWatch() async {
		let expectation = expectation(description: "ConfigMap Events")

		let task = Task {
			var records: [Record] = []
			do {
				let watchTask = try K3dTestCase.client.configMaps.watch(in: .namespace("cm3"))
				for try await event in await watchTask.start() {
					let record = Record(eventType: event.type, resource: event.resource.metadata!.name!)
					records.append(record)

					if records.count == 5 {
						expectation.fulfill()
						break
					}
				}
				return records
			} catch {
				return []
			}
		}

		try? _ = await K3dTestCase.client.configMaps.create(inNamespace: .namespace("cm3"), buildConfigMap("test1"))
		try? _ = await K3dTestCase.client.configMaps.create(inNamespace: .namespace("cm3"), buildConfigMap("test2"))
		try? _ = await K3dTestCase.client.configMaps.delete(inNamespace: .namespace("cm3"), name: "test1")
		try? _ = await K3dTestCase.client.configMaps.update(inNamespace: .namespace("cm3"), buildConfigMap("test2", data: ["foo": "bar"]))

		await fulfillment(of: [expectation], timeout:10)

		task.cancel()
		let result = await task.result.get()

		assertEqual(result, [
			Record(eventType: .added, resource: "kube-root-ca.crt"),
			Record(eventType: .added, resource: "test1"),
			Record(eventType: .added, resource: "test2"),
			Record(eventType: .deleted, resource: "test1"),
			Record(eventType: .modified, resource: "test2"),
		])
	}

	private func buildConfigMap(_ name: String, data: [String: String]? = nil) -> core.v1.ConfigMap {
		return core.v1.ConfigMap(
			metadata: meta.v1.ObjectMeta(name: name),
			data: data
		)
	}

	struct Record: Hashable {
		let eventType: EventType
		let resource: String
	}
}
