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

// MARK: - ResourceType

internal enum ResourceType {
	case root, log, scale, status

	var path: String {
		switch self {
		case .root:
			return ""
		case .log:
			return "/log"
		case .scale:
			return "/scale"
		case .status:
			return "/status"
		}
	}
}

// MARK: - NamespaceStep

internal protocol NamespaceStep {
	func `in`(_ namespace: NamespaceSelector) -> MethodStep
}

// MARK: - MethodStep

internal protocol MethodStep {
	func toGet() -> GetStep
	func toWatch() -> GetStep
	func toFollow(pod: String, container: String?, timestamps: Bool, tailLines: Int?) -> GetStep
	func toPost() -> PostStep
	func toPut() -> PutStep
	func toDelete() -> DeleteStep
	func toLogs(pod: String, container: String?, previous: Bool, timestamps: Bool, tailLines: Int?) -> GetStep
}

// MARK: - GetStep

internal protocol GetStep {
	func resource(withName name: String?) -> GetStep
	func subResource(_ subType: ResourceType) -> GetStep
	func with(options: [ListOption]?) -> GetStep
	func with(options: [ReadOption]?) -> GetStep
	func build() throws -> KubernetesRequest
}

// MARK: - PostStep

internal protocol PostStep {
	func body<Resource: KubernetesAPIResource>(_ resource: Resource) -> PostStep
	func build() throws -> KubernetesRequest
}

// MARK: - PutStep

internal protocol PutStep {
	func resource(withName name: String?) -> PutStep
	func body(_ body: RequestBody) -> PutStep
	func build() throws -> KubernetesRequest
}

// MARK: - DeleteStep

internal protocol DeleteStep {
	func resource(withName name: String?) -> DeleteStep
	func with(options: meta.v1.DeleteOptions?) -> DeleteStep
	func build() throws -> KubernetesRequest
}

// MARK: - RequestBuilder

///
/// An internal class for building API request objects.
///
/// It assumes a correct usage and does only minimal sanity checks.
internal class RequestBuilder {

	let config: KubernetesClientConfig
	let gvr: GroupVersionResource
	var components: URLComponents?

	var namespace: NamespaceSelector!
	var method: HTTPMethod! {
		didSet {
			switch method {
			case .POST, .PUT, .PATCH:
				hasPayload = true
			default:
				hasPayload = false
			}
		}
	}

	var hasPayload = false

	var resourceName: String?
	var requestBody: RequestBody? {
		didSet {
			subResourceType = requestBody?.type
		}
	}

	var subResourceType: ResourceType?

	var containerName: String?
	var listOptions: [ListOption]?
	var readOptions: [ReadOption]?
	var deleteOptions: meta.v1.DeleteOptions?
	var watchFlag = false
	var followFlag = false
	var previousFlag = false
	var timestampsFlag = false
	var tailLinesFlag: Int?

	init(config: KubernetesClientConfig, gvr: GroupVersionResource) {
		self.config = config
		self.gvr = gvr
		self.components = URLComponents(url: config.masterURL, resolvingAgainstBaseURL: false)
	}
}

// MARK: NamespaceStep

extension RequestBuilder: NamespaceStep {

	/// Set the namespace for the pending request and move to the Method Step
	/// - Parameter namespace: The namespace for this request
	/// - Returns: The builder instance as MethodStep
	func `in`(_ namespace: NamespaceSelector) -> MethodStep {
		self.namespace = namespace
		return self as MethodStep
	}
}

// MARK: MethodStep

extension RequestBuilder: MethodStep {

	/// Set request method to  GET for the pending request
	/// - Returns:The builder instance as GetStep
	func toGet() -> GetStep {
		method = .GET
		return self as GetStep
	}

	/// Set request method to  POST for the pending request
	/// - Returns:The builder instance as PostStep
	func toPost() -> PostStep {
		method = .POST
		return self as PostStep
	}

	/// Set request method to  PUT for the pending request
	/// - Returns:The builder instance as PutStep
	func toPut() -> PutStep {
		method = .PUT
		return self as PutStep
	}

	/// Set request method to  DELETE for the pending request
	/// - Returns:The builder instance as DeleteStep
	func toDelete() -> DeleteStep {
		method = .DELETE
		return self as DeleteStep
	}

	/// Set request method to  GET and toggle the `watch` flag
	/// - Returns:The builder instance as GetStep
	func toWatch() -> GetStep {
		method = .GET
		watchFlag = true
		return self as GetStep
	}

	/// Set request method to  GET and notice the pod and container to follow for the pending request
	/// - Returns:The builder instance as GetStep
	func toFollow(pod: String, container: String?, timestamps: Bool = false, tailLines: Int? = nil) -> GetStep {
		method = .GET
		resourceName = pod
		containerName = container
		subResourceType = .log
		followFlag = true
		timestampsFlag = timestamps
		tailLinesFlag = tailLines
		return self as GetStep
	}

	func toLogs(pod: String, container: String?, previous: Bool = false, timestamps: Bool = false, tailLines: Int? = nil) -> GetStep {
		method = .GET
		resourceName = pod
		containerName = container
		subResourceType = .log
		previousFlag = previous
		timestampsFlag = timestamps
		tailLinesFlag = tailLines
		return self as GetStep
	}
}

// MARK: GetStep

extension RequestBuilder: GetStep {

	/// Set the name of the resource for the pending request
	/// - Parameter name: The name of the resource
	/// - Returns: The builder instance as GetStep
	func resource(withName name: String?) -> GetStep {
		resourceName = name
		return self as GetStep
	}

	/// Set the sub-reousrce type for the pending request
	/// - Parameter subType: The `ResourceType`
	/// - Returns: The builder instance as GetStep
	func subResource(_ subType: ResourceType) -> GetStep {
		subResourceType = subType
		return self as GetStep
	}

	/// Set the `ListOptions` for the pending request
	/// - Parameter options: The `ListOptions`
	/// - Returns: The builder instance as GetStep
	func with(options: [ListOption]?) -> GetStep {
		listOptions = options
		return self as GetStep
	}

	/// Set the `ReadOption` for the pending request
	/// - Parameter options: The `ReadOption`
	/// - Returns: The builder instance as GetStep
	func with(options: [ReadOption]?) -> GetStep {
		readOptions = options
		return self as GetStep
	}
}

// MARK: PostStep

extension RequestBuilder: PostStep {

	/// Set the body payload for the pending request
	/// - Parameter resource: The `KubernetesAPIResource` payload
	/// - Returns: The builder instance as PostStep
	func body<Resource: KubernetesAPIResource>(_ resource: Resource) -> PostStep {
		requestBody = .resource(payload: resource)
		return self as PostStep
	}
}

// MARK: PutStep

extension RequestBuilder: PutStep {

	/// Set the name of the resource for the pending request
	/// - Parameter name: The name of the resource
	/// - Returns: The builder instance as PutStep
	func resource(withName name: String?) -> PutStep {
		resourceName = name
		return self as PutStep
	}

	/// Set the body payload for the pending request
	/// - Parameter body: The `KubernetesAPIResource` payload or a `KubernetesResource` subresource payload
	/// - Returns: The builder instance as PostStep
	func body(_ body: RequestBody) -> PutStep {
		requestBody = body
		return self as PutStep
	}
}

// MARK: DeleteStep

extension RequestBuilder: DeleteStep {

	/// Set the name of the resource for the pending request
	/// - Parameter name: The name of the resource
	/// - Returns: The builder instance as DeleteStep
	func resource(withName name: String?) -> DeleteStep {
		resourceName = name
		return self as DeleteStep
	}

	/// Set the `DeleteOptions` for the pending request
	/// - Parameter options: The `DeleteOptions`
	/// - Returns: The builder instance as DeleteStep
	func with(options: meta.v1.DeleteOptions?) -> DeleteStep {
		deleteOptions = options
		return self as DeleteStep
	}
}

internal extension RequestBuilder {

	func build() throws -> KubernetesRequest {
		var temporaryComponents = components

		temporaryComponents?.path += urlPath(forNamespace: namespace, name: resourceName)

		if let subResourceType = subResourceType {
			temporaryComponents?.path += subResourceType.path
		}

		if let queryItems = components?.queryItems {
			temporaryComponents?.queryItems = queryItems
		}

		if requestBody?.type == .root {
			guard
				let body = requestBody,
				case let RequestBody.resource(payload: payload) = body,
				payload.name != nil
			else {
				throw SwiftkubeClientError.badRequest("Resource `metadata.name` must be set.")
			}
		}

		guard !(method == .DELETE && requestBody != nil) else {
			throw SwiftkubeClientError.badRequest("RequestBody can't be set for DELETE call.")
		}

		if let readOptions = readOptions {
			readOptions.collectQueryItems().forEach { add(queryItem: $0, to: &temporaryComponents) }
		}

		if let listOptions = listOptions {
			listOptions.collectQueryItems().forEach { add(queryItem: $0, to: &temporaryComponents) }
		}

		if watchFlag {
			add(queryItem: URLQueryItem(name: "watch", value: "true"), to: &temporaryComponents)
		}

		if followFlag {
			add(queryItem: URLQueryItem(name: "follow", value: "true"), to: &temporaryComponents)
		}

		if previousFlag {
			add(queryItem: URLQueryItem(name: "previous", value: "true"), to: &temporaryComponents)
		}

		if timestampsFlag {
			add(queryItem: URLQueryItem(name: "timestamps", value: "true"), to: &temporaryComponents)
		}

		if let tailLinesFlag {
			add(queryItem: URLQueryItem(name: "tailLines", value: String(tailLinesFlag)), to: &temporaryComponents)
		}

		if let container = containerName {
			add(queryItem: URLQueryItem(name: "container", value: container), to: &temporaryComponents)
		}

		if (temporaryComponents?.url?.absoluteString) == nil {
			throw SwiftkubeClientError.invalidURL
		}

		let headers = buildHeaders(withAuthentication: config.authentication)

		return KubernetesRequest(
			url: (temporaryComponents?.url)!,
			method: method,
			headers: headers,
			body: requestBody,
			deleteOptions: deleteOptions
		)
	}

	private func urlPath(forNamespace namespace: NamespaceSelector, name: String?) -> String {
		var url: String

		if case NamespaceSelector.allNamespaces = namespace {
			url = "\(gvr.urlPath)/\(gvr.resource)"
		} else {
			url = "\(gvr.urlPath)/namespaces/\(namespace.namespaceName())/\(gvr.resource)"
		}

		if let name = name {
			url += "/\(name)"
		}

		return url
	}

	private func add(queryItem: URLQueryItem, to components: inout URLComponents?) {
		if components?.queryItems == nil {
			components?.queryItems = []
		}
		components?.queryItems?.append(queryItem)
	}

	private func buildHeaders(withAuthentication authentication: KubernetesClientAuthentication?) -> HTTPHeaders {
		var headers: [(String, String)] = []
		if let authorizationHeader = authentication?.authorizationHeader() {
			headers.append(("Authorization", authorizationHeader))
		}

		return HTTPHeaders(headers)
	}
}
