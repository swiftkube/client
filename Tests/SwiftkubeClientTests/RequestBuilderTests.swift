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

import AsyncHTTPClient
import NIO
import NIOHTTP1
@testable import SwiftkubeClient
import SwiftkubeModel
import XCTest

final class RequestBuilderTests: XCTestCase {

	var config: KubernetesClientConfig!
	var gvr: GroupVersionResource!

	override func setUp() {
		config = KubernetesClientConfig(
			masterURL: URL(string: "https://kubernetesmaster")!,
			namespace: "default",
			authentication: .basicAuth(username: "test", password: "test"),
			trustRoots: nil,
			insecureSkipTLSVerify: false,
			timeout: .init(connect: .seconds(1), read: .seconds(5)),
			redirectConfiguration: .disallow
		)

		gvr = GroupVersionResource(of: core.v1.Pod.self)!
	}

	func testGetInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		var request = try? builder.in(.default).toGet().build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)

		request = try? builder.in(.system).toGet().build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testGetInAllNamespaces() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.allNamespaces).toGet().build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/pods")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testGetInNamespaceWithName() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		var request = try? builder.in(.default).toGet().resource(withName: "test").build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods/test")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)

		request = try? builder.in(.system).toGet().build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/test")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testFollowInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.system).toFollow(pod: "pod", container: "container", timestamps: false).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/pod/log?follow=true&container=container")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

		func testFollowWithTimestampsInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.system).toFollow(pod: "pod", container: "container", timestamps: true).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/pod/log?follow=true&timestamps=true&container=container")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}
	
	func testLogsInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.system).toLogs(pod: "pod", container: nil, previous: false, timestamps: false).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/pod/log")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}
	
	func testLogsWithContainerInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.system).toLogs(pod: "pod", container: "container", previous: false, timestamps: false).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/pod/log?container=container")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testLogsWithPreviousInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.system).toLogs(pod: "pod", container: nil, previous: true, timestamps: false).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/pod/log?previous=true")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testLogsWithTimestampsInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.system).toLogs(pod: "pod", container: nil, previous: false, timestamps: true).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/pod/log?timestamps=true")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testGetWithListOptions_Eq() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.labelSelector(.eq(["app": "nginx"])),
		])
			.build()

		XCTAssertEqual(request?.url.query, "labelSelector=app%3Dnginx")
	}

	func testGetWithListOptions_NotEq() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.labelSelector(.neq(["app": "nginx"])),
		])
			.build()

		XCTAssertEqual(request?.url.query, "labelSelector=app!%3Dnginx")
	}

	func testGetWithListOptions_In() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.labelSelector(.in(["env": ["dev", "staging"]])),
		])
			.build()
		XCTAssertEqual(request?.url.query, "labelSelector=env%20in%20(dev,staging)")
	}

	func testGetWithListOptions_NotIn() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.labelSelector(.notIn(["env": ["dev", "staging"]])),
		])
			.build()
		XCTAssertEqual(request?.url.query, "labelSelector=env%20notin%20(dev,staging)")
	}

	func testGetWithListOptions_Exists() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.labelSelector(.exists(["app", "env"])),
		])
			.build()

		XCTAssertEqual(request?.url.query, "labelSelector=app,env")
	}

	func testGetWithListOptions_FieldEq() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.fieldSelector(.eq(["app": "nginx"])),
		])
			.build()

		XCTAssertEqual(request?.url.query, "fieldSelector=app%3Dnginx")
	}

	func testGetWithListOptions_FieldNotEq() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.fieldSelector(.neq(["app": "nginx"])),
		])
			.build()

		XCTAssertEqual(request?.url.query, "fieldSelector=app!%3Dnginx")
	}

	func testGetWithListOptions_Limit() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.limit(2),
		])
			.build()

		XCTAssertEqual(request?.url.query, "limit=2")
	}

	func testGetWithListOptions_Version() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().with(options: [
			.resourceVersion("20"),
		])
			.build()

		XCTAssertEqual(request?.url.query, "resourceVersion=20")
	}

	func testGetStatus() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().resource(withName: "test").subResource(.status).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods/test/status")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testGetScale() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.default).toGet().resource(withName: "test").subResource(.scale).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods/test/scale")!)
		XCTAssertEqual(request?.method, HTTPMethod.GET)
	}

	func testDeleteInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		var request = try? builder.in(.default).toDelete().resource(withName: "test").build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods/test")!)
		XCTAssertEqual(request?.method, HTTPMethod.DELETE)

		request = try? builder.in(.system).toDelete().build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/kube-system/pods/test")!)
		XCTAssertEqual(request?.method, HTTPMethod.DELETE)
	}

	func testDeleteInAllNamespaces() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let request = try? builder.in(.allNamespaces).toDelete().build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/pods")!)
		XCTAssertEqual(request?.method, HTTPMethod.DELETE)
	}

	func testCreateInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let pod = sk.pod(name: "test")
		let request = try? builder.in(.default).toPost().body(pod).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods")!)
		XCTAssertEqual(request?.method, HTTPMethod.POST)
	}

	func testReplaceInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let pod = sk.pod(name: "test")
		let request = try? builder.in(.default).toPut().resource(withName: "test").body(.resource(payload: pod)).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods/test")!)
		XCTAssertEqual(request?.method, HTTPMethod.PUT)
	}

	func testReplaceStatusInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let pod = sk.pod(name: "test")
		let request = try? builder.in(.default).toPut().resource(withName: "test").body(.subResource(type: .status, payload: pod)).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods/test/status")!)
		XCTAssertEqual(request?.method, HTTPMethod.PUT)
	}

	func testReplaceScaleInNamespace() {
		let builder = RequestBuilder(config: config, gvr: gvr)
		let pod = sk.pod(name: "test")
		let request = try? builder.in(.default).toPut().resource(withName: "test").body(.subResource(type: .scale, payload: pod)).build()

		XCTAssertEqual(request?.url, URL(string: "https://kubernetesmaster/api/v1/namespaces/default/pods/test/scale")!)
		XCTAssertEqual(request?.method, HTTPMethod.PUT)
	}
}
