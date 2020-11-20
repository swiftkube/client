//
// Copyright 2020 Iskandar Abudiab (iabudiab.dev)
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

internal class RequestBuilder<Resource: KubernetesAPIResource> {

	let config: KubernetesClientConfig
	let gvk: GroupVersionKind

	var resource: Resource?
	var resourceName: String?
	var listSelector: ListSelector?
	var method: HTTPMethod!
	var namespace: NamespaceSelector!
	var watch: Bool = false
	var follow: Bool = false
	var container: String?

	init(config: KubernetesClientConfig, gvk: GroupVersionKind) {
		self.config = config
		self.gvk = gvk
	}

	func to(_ method: HTTPMethod) -> RequestBuilder {
		self.method = method
		return self
	}

	func toWatch() -> RequestBuilder {
		self.method = .GET
		self.watch = true
		return self
	}

	func toFollow(pod: String, container: String?) -> RequestBuilder {
		self.method = .GET
		self.resourceName = pod
		self.container = container
		self.follow = true
		return self
	}

	func resource(_ resource: Resource) -> RequestBuilder {
		self.resource = resource
		return self
	}

	func resource(withName name: String) -> RequestBuilder {
		self.resourceName = name
		return self
	}

	func `in`(_ namespace: NamespaceSelector) -> RequestBuilder {
		self.namespace = namespace
		return self
	}

	func filter(by listSelector: ListSelector?) -> RequestBuilder {
		self.listSelector = listSelector
		return self
	}

	func build() throws -> HTTPClient.Request {
		var components = URLComponents(url: config.masterURL, resolvingAgainstBaseURL: false)
		components?.path = urlPath(forNamespace: namespace, name: resourceName, follow: follow)

		guard !(method.hasRequestBody && resourceName == nil) else {
			throw SwiftkubeClientError.badRequest("Resource `metadata.name` must be set.")
		}

		if let listSelector = listSelector {
			components?.queryItems = [URLQueryItem(name: listSelector.name, value: listSelector.value)]
		}

		if watch {
			components?.queryItems?.append(URLQueryItem(name: "watch", value: "true"))
		}

		if follow {
			components?.queryItems?.append(URLQueryItem(name: "follow", value: "true"))
			// TODO Make configurable
			components?.queryItems?.append(URLQueryItem(name: "pretty", value: "true"))
		}

		if let container = container {
			components?.queryItems?.append(URLQueryItem(name: "container", value: container))
		}

		guard let url = components?.url?.absoluteString else {
			throw SwiftkubeClientError.invalidURL
		}

		let headers = buildHeaders(withAuthentication: config.authentication)
		var body: HTTPClient.Body? = nil

		if let resource = resource {
			let data = try JSONEncoder().encode(resource)
			body = .data(data)
		}

		return try HTTPClient.Request(url: url, method: method, headers: headers, body: body)
	}

	func urlPath(forNamespace namespace: NamespaceSelector, name: String?, follow: Bool) -> String {
		let listURL: String
		switch namespace {
		case .allNamespaces:
			listURL = "\(gvk.urlPath)/\(gvk.pluralName)"
		default:
			listURL = "\(gvk.urlPath)/namespaces/\(namespace.namespaceName())/\(gvk.pluralName)"
		}

		if let name = name {
			return "\(listURL)/\(name)"
		} else {
			return listURL
		}
	}

	func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
		var headers: [(String, String)] = []
		if let authorizationHeader = authentication?.authorizationHeader() {
			headers.append(("Authorization", authorizationHeader))
		}

		return HTTPHeaders(headers)
	}
}
