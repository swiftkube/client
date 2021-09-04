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

open class K3dTestCase: XCTestCase {

	static var client: KubernetesClient!

	open override class func setUp() {
		client = KubernetesClient()!
	}

	open override class func tearDown() {
		try? client.syncShutdown()
	}

	@discardableResult
	public static func createNamespace(_ name: String, labels: [String: String]? = nil) -> core.v1.Namespace? {
		try? client.namespaces.create(core.v1.Namespace(metadata: meta.v1.ObjectMeta(labels: labels, name: name))).wait()
	}

	public static func deleteNamespace(_ name: String) {
		_ = try? client.namespaces.delete(
			name: name,
			options: meta.v1.DeleteOptions(gracePeriodSeconds: 0, propagationPolicy: "Foreground")
		)
		.wait()
	}

	func assertEqual<S: Sequence>(_ lhs: S?, _ rhs: S?, file: StaticString = #file, line: UInt = #line) where S.Element: Hashable {
		XCTAssert(
			Set(lhs ?? [] as! S) == Set(rhs ?? [] as! S),
			"\(String(describing: lhs)) is not equal to \(String(describing: rhs))",
			file: file,
			line: line
		)
	}
}
