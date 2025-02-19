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
import NIO
import SwiftkubeClient
import SwiftkubeModel
import XCTest

open class K8sTestCase: XCTestCase {

	#if compiler(>=6.0)
	nonisolated(unsafe) static var logger: Logger!
	nonisolated(unsafe) static var client: KubernetesClient!
	#else
	static var logger: Logger!
	static var client: KubernetesClient!
	#endif

	static let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

	open override class func setUp() {
		logger = Logger(label: "swiftkubeclient-test")
		client = KubernetesClient(logger: logger)!
	}

	open override class func tearDown() {
		try? client.syncShutdown()
	}

	@discardableResult
	public static func createNamespace(_ name: String, labels: [String: String]? = nil) -> core.v1.Namespace? {
		do {
			print("Creating namespace: \(name)")
			let future = eventLoopGroup.next().makeFutureWithTask { () -> core.v1.Namespace in
				try await client.namespaces.create(core.v1.Namespace(metadata: meta.v1.ObjectMeta(labels: labels, name: name)))
			}

			let namespace = try future.wait()
			return namespace
		} catch let error {
			print("Error creating namespace \(name): \(error)")
			return nil
		}
	}

	public static func deleteNamespace(_ name: String) {
		do {
			print("Deleting namespace: \(name)")

			try eventLoopGroup.next().makeFutureWithTask { () -> Void in
				try? await client.namespaces.delete(
					name: name,
					options: meta.v1.DeleteOptions(gracePeriodSeconds: 0, propagationPolicy: "Foreground")
				)
			}.wait()

			try wait(timeout: .seconds(30)) {
				let deletedFuture = eventLoopGroup.next().makeFutureWithTask { () -> Bool in
					let namespaces = try! await client.namespaces.list().items.map(\.name)
					return !namespaces.contains(name)
				}

				return try deletedFuture.wait()
			}

		} catch let error {
			print("Error deleting namespace \(name): \(error)")
		}
	}

	static func wait(timeout: DispatchTimeInterval, condition: () throws -> Bool) rethrows {
		let start = DispatchTime.now()

		while !(try condition()) {
			sleep(2)
			let now = DispatchTime.now()
			let diff = now.uptimeNanoseconds - start.uptimeNanoseconds
			if diff > timeout.nanoseconds() {
				return
			}
		}
	}

	func assertEqual<S: Sequence>(_ lhs: S?, _ rhs: S?, file: StaticString = #filePath, line: UInt = #line) where S.Element: Hashable {
		XCTAssert(
			Set(lhs ?? [] as! S) == Set(rhs ?? [] as! S),
			"\(String(describing: lhs)) is not equal to \(String(describing: rhs))",
			file: file,
			line: line
		)
	}
}

extension DispatchTimeInterval {

	func nanoseconds() -> UInt64 {
		switch self {
		case .seconds(let value):
			return UInt64(value * 1_000_000_000)
		case .milliseconds(let value):
			return UInt64(value * 1_000_000)
		case .microseconds(let value):
			return UInt64(value * 1_000)
		case .nanoseconds(let value):
			return UInt64(value)
		case .never:
			return 0
		@unknown default:
			return 0
		}
	}
}
