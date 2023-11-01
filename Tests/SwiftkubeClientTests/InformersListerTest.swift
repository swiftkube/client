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

final class InformersListerTest: XCTestCase {

	func testLister() {
		let cache = Cache<core.v1.Pod>()
		let podLister = Lister(namespace: .default, indexer: cache)

		try? cache.replace(with: [
			core.v1.Pod(metadata: .init(name: "pod-1", namespace: "default")),
			core.v1.Pod(metadata: .init(name: "pod-2", namespace: "default")),
			core.v1.Pod(metadata: .init(name: "pod-3", namespace: "default")),
		], resourceVersion: "0")

		let namespacePodList = try? podLister.list()

		XCTAssertEqual(3, namespacePodList?.count)
	}

	func testAllNamespacesLister() {
		let cache = Cache<core.v1.Pod>()
		let podLister = Lister(indexer: cache)

		try? cache.replace(with: [
			core.v1.Pod(metadata: .init(name: "pod-1", namespace: "ns-1")),
			core.v1.Pod(metadata: .init(name: "pod-2", namespace: "ns-2")),
			core.v1.Pod(metadata: .init(name: "pod-3", namespace: "ns-2")),
		], resourceVersion: "0")

		let namespacePodList = try? podLister.list()

		XCTAssertEqual(3, namespacePodList?.count)
	}

	func testListerChangeNamespace() {
		let cache = Cache<core.v1.Pod>()
		let podLister = Lister(indexer: cache)

		try? cache.replace(with: [
			core.v1.Pod(metadata: .init(name: "pod-1", namespace: "ns-1")),
			core.v1.Pod(metadata: .init(name: "pod-2", namespace: "ns-2")),
			core.v1.Pod(metadata: .init(name: "pod-3", namespace: "ns-2")),
		], resourceVersion: "0")

		let namespacePodList = try? podLister.namespace(.namespace("ns-2")).list()

		XCTAssertEqual(2, namespacePodList?.count)
	}
}
