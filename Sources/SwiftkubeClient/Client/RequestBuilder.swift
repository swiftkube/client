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
import Foundation
import NIO
import NIOHTTP1
import SwiftkubeModel

extension HTTPMethod {

	var hasRequestBody: Bool {
		switch self {
		case .POST, .PUT, .PATCH:
			return true
		default:
			return false
		}
	}
}

// MARK: - RequestBuilder

///
/// An internal class for building API request objects.
///
/// It assumes a correct usage and does only minimal sanity checks.
internal class RequestBuilder<Resource: KubernetesAPIResource> {

	let config: KubernetesClientConfig
	let gvk: GroupVersionKind
	var components: URLComponents?

	var method: HTTPMethod!
	var namespace: NamespaceSelector!
	var resource: Resource?
	var resourceName: String?
	var listOptions: [ListOption]?
	var readOptions: [ReadOption]?
	var deleteOptions: meta.v1.DeleteOptions?
	var statusRequest: Bool = false
	var watchRequest: Bool = false
	var followRequest: Bool = false
	var container: String?

	init(config: KubernetesClientConfig, gvk: GroupVersionKind) {
		self.config = config
		self.gvk = gvk
		self.components = URLComponents(url: config.masterURL, resolvingAgainstBaseURL: false)
	}

	func to(_ method: HTTPMethod) -> RequestBuilder {
		self.method = method
		return self
	}

	func status() -> RequestBuilder {
		statusRequest = true
		return self
	}

	func toWatch() -> RequestBuilder {
		method = .GET
		watchRequest = true
		return self
	}

	func toFollow(pod: String, container: String?) -> RequestBuilder {
		method = .GET
		resourceName = pod
		self.container = container
		followRequest = true
		return self
	}

	func resource(_ resource: Resource) -> RequestBuilder {
		self.resource = resource
		return self
	}

	func resource(withName name: String?) -> RequestBuilder {
		resourceName = name
		return self
	}

	func `in`(_ namespace: NamespaceSelector) -> RequestBuilder {
		self.namespace = namespace
		return self
	}

	func with(options: [ListOption]?) -> RequestBuilder {
		listOptions = options
		return self
	}

	func with(options: [ReadOption]?) -> RequestBuilder {
		readOptions = options
		return self
	}

	func with(options: meta.v1.DeleteOptions?) -> RequestBuilder {
		deleteOptions = options
		return self
	}

	func build() throws -> HTTPClient.Request {
		components?.path = urlPath(forNamespace: namespace, name: resourceName)

		if statusRequest {
			components?.path += "/status"
		}

		if followRequest {
			components?.path += "/log"
		}

		guard !(method.hasRequestBody && resource?.name == nil) else {
			throw SwiftkubeClientError.badRequest("Resource `metadata.name` must be set.")
		}

		guard !(method == .DELETE && resource != nil) else {
			throw SwiftkubeClientError.badRequest("Resource can't be set for DELETE call.")
		}

		if let readOptions = readOptions {
			readOptions.collectQueryItems().forEach(add(queryItem:))
		}

		if let listOptions = listOptions {
			listOptions.collectQueryItems().forEach(add(queryItem:))
		}

		if watchRequest {
			add(queryItem: URLQueryItem(name: "watch", value: "true"))
		}

		if followRequest {
			add(queryItem: URLQueryItem(name: "follow", value: "true"))
		}

		if let container = container {
			add(queryItem: URLQueryItem(name: "container", value: container))
		}

		guard let url = components?.url?.absoluteString else {
			throw SwiftkubeClientError.invalidURL
		}

		let headers = buildHeaders(withAuthentication: config.authentication)
		var body: HTTPClient.Body?

		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		if let resource = resource {
			let data = try encoder.encode(resource)
			body = .data(data)
		}

		if let options = deleteOptions {
			let data = try encoder.encode(options)
			body = .data(data)
		}

		return try HTTPClient.Request(url: url, method: method, headers: headers, body: body)
	}

	func urlPath(forNamespace namespace: NamespaceSelector, name: String?) -> String {
		var url: String

		if case NamespaceSelector.allNamespaces = namespace {
			url = "\(gvk.urlPath)/\(gvk.pluralName)"
		} else {
			url = "\(gvk.urlPath)/namespaces/\(namespace.namespaceName())/\(gvk.pluralName)"
		}

		if let name = name {
			url += "/\(name)"
		}

		return url
	}

	func add(queryItem: URLQueryItem) {
		if components?.queryItems == nil {
			components?.queryItems = []
		}
		components?.queryItems?.append(queryItem)
	}

	func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
		var headers: [(String, String)] = []
		if let authorizationHeader = authentication?.authorizationHeader() {
			headers.append(("Authorization", authorizationHeader))
		}

		return HTTPHeaders(headers)
	}
}
