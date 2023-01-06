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

		wait(for: [deletedConfigMap], timeout: 10)
	}

	func testWatch() async {
		let expectedRecords = expectation(description: "Expected Records")
		let watcher = Watcher(logger: K3dConfigMapTests.logger, expectation: expectedRecords, expectedCount: 5)

		let task = try? K3dTestCase.client.configMaps.watch(in: .namespace("cm3"), delegate: watcher)

		try? _ = await K3dTestCase.client.configMaps.create(inNamespace: .namespace("cm3"), buildConfigMap("test1"))
		try? _ = await K3dTestCase.client.configMaps.create(inNamespace: .namespace("cm3"), buildConfigMap("test2"))
		try? _ = await K3dTestCase.client.configMaps.delete(inNamespace: .namespace("cm3"), name: "test1")
		try? _ = await K3dTestCase.client.configMaps.update(inNamespace: .namespace("cm3"), buildConfigMap("test2", data: ["foo": "bar"]))

		wait(for: [watcher.expectedRecords], timeout: 30)
		task?.cancel()

		assertEqual(watcher.records, [
			Watcher.Record(eventType: .added, resource: "kube-root-ca.crt"),
			Watcher.Record(eventType: .added, resource: "test1"),
			Watcher.Record(eventType: .added, resource: "test2"),
			Watcher.Record(eventType: .deleted, resource: "test1"),
			Watcher.Record(eventType: .modified, resource: "test2"),
		])
	}

	private func buildConfigMap(_ name: String, data: [String: String]? = nil) -> core.v1.ConfigMap {
		return core.v1.ConfigMap(
			metadata: meta.v1.ObjectMeta(name: name),
			data: data
		)
	}

	class Watcher: ResourceWatcherDelegate {

		struct Record: Hashable {
			let eventType: EventType
			let resource: String
		}

		let logger: Logger
		let expectedRecords: XCTestExpectation
		var expectedCount: Int
		var records: [Record] = []

		init(logger: Logger, expectation: XCTestExpectation, expectedCount: Int) {
			self.logger = logger
			self.expectedRecords = expectation
			self.expectedCount = expectedCount
		}

		func onEvent(event: EventType, resource: core.v1.ConfigMap) {
			records.append(Record(eventType: event, resource: resource.name!))
			if records.count == expectedCount {
				expectedRecords.fulfill()
			}
		}

		func onError(error: SwiftkubeClientError) {
			logger.warning("Error encountered: \(error)")
		}
	}
}
