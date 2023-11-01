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
@testable import SwiftkubeModel
import XCTest

final class InformersCacheTest: XCTestCase {

	let indexFunction: IndexFuntion<core.v1.Pod> = { pod in
		return [pod.name!]
	}

	let keyFunction: KeyFuntion<core.v1.Pod> = { pod in
		return pod.name!.hashValue.description
	}

	func testAdd() {
		let cache = Cache<core.v1.Pod>(indexName: "test", indexFunction: indexFunction, keyFunction: keyFunction)

		let pod1 = core.v1.Pod(
			metadata: .init(
				name: "nginx"
			)
		)

		try? cache.add(pod1)
		let key1 = try! keyFunction(pod1)

		XCTAssertNotNil(cache.get(byKey: key1))

		let pod2 = core.v1.Pod(
			metadata: .init(
				name: "nginx"
			)
		)

		try? cache.add(pod2)
		let key2 = try! keyFunction(pod2)

		XCTAssertNotNil(cache.get(byKey: key2))

		XCTAssertEqual(try? cache.get(pod1), pod1)
		XCTAssertEqual(cache.get(byKey: key2), pod2)
	}

	func testDelete() {
		let cache = Cache<core.v1.Pod>(indexName: "test", indexFunction: indexFunction, keyFunction: keyFunction)

		let pod1 = core.v1.Pod(
			metadata: .init(
				name: "nginx-1"
			)
		)

		let pod2 = core.v1.Pod(
			metadata: .init(
				name: "nginx-2"
			)
		)

		try? cache.add(pod1)
		try? cache.add(pod2)
		try? cache.delete(pod1)

		XCTAssertNil(cache.get(byKey: pod1.hashValue.description))
		XCTAssertNotNil(cache.get(byKey: try! keyFunction(pod2)))
	}

	func testUpdate() {
		let cache = Cache<core.v1.Pod>(indexName: "test", indexFunction: indexFunction, keyFunction: keyFunction)

		var pod = core.v1.Pod(
			metadata: .init(
				name: "nginx-1"
			)
		)

		try? cache.add(pod)

		pod.metadata?.namespace = "test"

		try? cache.update(pod)
		let key = try! keyFunction(pod)

		let cached = cache.get(byKey: key)
		XCTAssertNotNil(cached)
		XCTAssertEqual("test", cached?.metadata?.namespace)
	}

	func testList() {
		let cache = Cache<core.v1.Pod>(indexName: "test", indexFunction: indexFunction, keyFunction: keyFunction)

		let pod1 = core.v1.Pod(
			metadata: .init(
				name: "nginx-1"
			)
		)

		let pod2 = core.v1.Pod(
			metadata: .init(
				name: "nginx-2"
			)
		)

		try? cache.add(pod1)
		try? cache.add(pod2)

		let cached = cache.list().map { $0.metadata?.name }

		XCTAssertTrue(cached.contains(["nginx-1", "nginx-2"]))
		XCTAssertTrue(["nginx-1", "nginx-2"].contains(cached))
	}

	func testListKeys() {
		let cache = Cache<core.v1.Pod>(indexName: "test", indexFunction: indexFunction, keyFunction: keyFunction)

		let pod1 = core.v1.Pod(
			metadata: .init(
				name: "nginx-1"
			)
		)

		let pod2 = core.v1.Pod(
			metadata: .init(
				name: "nginx-2"
			)
		)

		try? cache.add(pod1)
		try? cache.add(pod2)

		let cached = cache.listKeys()
		let key1 = try! keyFunction(pod1)
		let key2 = try! keyFunction(pod2)

		XCTAssertTrue([key1, key2].contains(cached))
		XCTAssertTrue(cached.contains([key1, key2]))
	}

	func testIndex() {
		let cache = Cache<core.v1.Pod>(indexName: "test", indexFunction: indexFunction, keyFunction: keyFunction)

		let pod = core.v1.Pod(
			metadata: .init(
				name: "nginx-1"
			)
		)

		try? cache.add(pod)
		try? cache.replace(with: [pod], resourceVersion: "0")

		let index = try! indexFunction(pod).first!
		let key = try! keyFunction(pod)

		var indexedPods = cache.byIndex(indexName: "test", indexedValue: index)
		XCTAssertEqual(pod, indexedPods.first)

		indexedPods = try! cache.index(indexName: "test", item: pod)
		XCTAssertEqual(pod, indexedPods.first)

		let keys = cache.listKeys()
		XCTAssertEqual(1, keys.count)
		XCTAssertEqual(key, keys.first)
	}

	func testStore() {
		let cache = Cache<core.v1.Pod>(indexName: "test", indexFunction: indexFunction, keyFunction: keyFunction)

		var pod = core.v1.Pod(
			metadata: .init(
				name: "nginx-1"
			)
		)

		try? cache.replace(with: [pod], resourceVersion: "0")
		try? cache.delete(pod)

		let index = try! indexFunction(pod).first!

		let indexedPods = cache.byIndex(indexName: "test", indexedValue: index)
		XCTAssertEqual(0, indexedPods.count)

		try? cache.add(pod)

		pod.metadata?.namespace = "network"
		try? cache.update(pod)

		XCTAssertEqual(1, cache.list().count)
	}

	func testNamespaceIndexAndKey() {
		var pod = core.v1.Pod(
			metadata: .init(
				name: "nginx-1"
			)
		)

		XCTAssertEqual([], try ObjectMetaNamespaceIndexFunction(
			core.v1.Pod(
				metadata: .init(
					name: "nginx-1"
				)
			)
		))

		XCTAssertThrowsError(try ObjectMetaNamespaceKeyFunction(
			core.v1.Pod(
				metadata: .init(
					name: "nginx-1"
				)
			)
		))

		XCTAssertEqual(["test-ns"], try ObjectMetaNamespaceIndexFunction(
			core.v1.Pod(
				metadata: .init(
					name: "nginx-1",
					namespace: "test-ns"
				)
			)
		))

		XCTAssertEqual("test-ns/nginx-1", try ObjectMetaNamespaceKeyFunction(
			core.v1.Pod(
				metadata: .init(
					name: "nginx-1",
					namespace: "test-ns"
				)
			)
		))
	}
}
