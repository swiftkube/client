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

final class K3dServiceTests: K3dTestCase {

	let deployment = buildDeployment()

	override class func setUp() {
		super.setUp()

		// ensure clean state
		deleteNamespace("svc1")

		// create namespaces for tests
		createNamespace("svc1")
	}

	func testListCreate() async {
		try? _ = await K3dTestCase.client.appsV1.deployments.create(in: .namespace("svc1"), deployment)

		for service in [
			buildService(name: "svc1", port: 8080, deploy: deployment),
			buildService(name: "svc2", port: 9090, deploy: deployment),
		] {
			try? _ = await K3dTestCase.client.services.create(inNamespace: .namespace("svc1"), service)
		}

		let services = try? await K3dTestCase.client.services.list(in: .namespace("svc1"))

		let names = services?.items.map { $0.name }
		assertEqual(names, ["svc1", "svc2"])

		let ports = services?.items.flatMap { $0.spec?.ports ?? [] }.map {$0.port}
		assertEqual(ports, [8080, 9090])
	}

	func testDelete() async {
		try? _ = await K3dTestCase.client.appsV1.deployments.create(in: .namespace("svc1"), deployment)

		let service = try? await K3dTestCase.client.services.create(
			inNamespace: .namespace("svc1"),
			buildService(name: "deleteme", port: 8080, deploy: deployment)
		)

		XCTAssertNotNil(service)

		let _ = try! await K3dTestCase.client.services.delete(inNamespace: .namespace("svc1"), name: "deleteme")

		let deletedService = expectation(description: "Deleted Service")

		do {
			let _ = try await K3dTestCase.client.configMaps.get(in: .namespace("svc1"), name: "deleteme")
		} catch let error {
			guard case let SwiftkubeClientError.statusError(status) = error, status.code == 404 else {
				return
			}

			deletedService.fulfill()
		}

		wait(for: [deletedService], timeout: 10)
	}

	private func buildService(name: String, port: Int32, deploy: apps.v1.Deployment) -> core.v1.Service {
		return core.v1.Service(
			metadata: .init(name: name),
			spec: .init(
				ports: [
					.init(port: port)
				],
				selector: deploy.metadata?.labels
			)
		)
	}

	private static func buildDeployment() -> apps.v1.Deployment {
		return apps.v1.Deployment(
			metadata: .init(labels: ["app": "nginx"], name: "nginx"),
			spec: .init(
				replicas: 1,
				selector: .init(matchLabels: ["app": "nginx"]),
				template: .init(
					metadata: .init(labels: ["app": "nginx"]),
					spec: .init(containers: [
						.init(image: "nginx", name: "nginx")
					])
				)
			)
		)
	}
}
