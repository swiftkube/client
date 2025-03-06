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
import Logging
import NIO
import SwiftkubeModel

// MARK: - Info

/// Holds information about the kubernetes API server version when calling ``DiscoveryAPI/serverVersion()``.
public struct Info: Codable, Sendable {
	public let major: String
	public let minor: String
	public let gitVersion: String
	public let gitCommit: String
	public let gitTreeState: String
	public let buildDate: String
	public let goVersion: String
	public let compiler: String
	public let platform: String
}

// MARK: - DiscoveryAPI

/// Exposed discovery API of the internal discovery client.
public protocol DiscoveryAPI {

	/// Loads ``Info`` about the kubernetes API server.
	///
	/// - Returns: A ``Info`` instance.
	func serverVersion() async throws -> Info

	/// Loads a ``meta.v1.APIGroupList`` describing the available API Groups.
	///
	/// - Returns: A ``meta.v1.APIGroupList`` instance.
	func serverGroups() async throws -> meta.v1.APIGroupList

	/// Loads a list of ``meta.v1.APIResourceList`` resources describing the available API Resources.
	///
	/// - Returns: A list of ``meta.v1.APIResourceList`` resources.
	func serverResources() async throws -> [meta.v1.APIResourceList]

	/// Loads ``meta.v1.APIResourceList`` describing the available resources for the given  version.
	///
	/// - Parameters:
	///   - groupVersion: The version of the API group
	///
	/// - Returns:A ``meta.v1.APIResourceList`` instance.
	func serverResources(forGroupVersion groupVersion: String) async throws -> meta.v1.APIResourceList
}

// MARK: - KubernetesClient

public extension KubernetesClient {

	/// Constructs a client fot ``DiscoveryAPI``.
	nonisolated var discoveryClient: DiscoveryAPI {
		DiscoveryClient(httpClient: httpClient, config: config, jsonDecoder: jsonDecoder, logger: logger)
	}
}

// MARK: - DiscoveryClient

internal class DiscoveryClient: DiscoveryAPI, RequestHandlerType {

	internal let httpClient: HTTPClient
	internal let config: KubernetesClientConfig
	internal let jsonDecoder: JSONDecoder
	internal let logger: Logger

	init(httpClient: HTTPClient, config: KubernetesClientConfig, jsonDecoder: JSONDecoder, logger: Logger) {
		self.httpClient = httpClient
		self.config = config
		self.jsonDecoder = jsonDecoder
		self.logger = logger
	}

	func serverVersion() async throws -> Info {
		let request = try makeRequest().path("/version").build()
		return try await dispatch(request: request, expect: Info.self)
	}

	func serverGroups() async throws -> meta.v1.APIGroupList {
		let legacyAPIVersionsRequest = try makeRequest().path("/api").build()
		let apiGroupListRequest = try makeRequest().path("/apis").build()

		let apiVersions = try await dispatch(request: legacyAPIVersionsRequest, expect: meta.v1.APIVersions.self)
		let apiGroupList = try await dispatch(request: apiGroupListRequest, expect: meta.v1.APIGroupList.self)

		let groupVersions = apiVersions.versions.map { version in
			meta.v1.GroupVersionForDiscovery(groupVersion: version, version: version)
		}

		let legacyAPIGroup = meta.v1.APIGroup(
			name: "",
			preferredVersion: groupVersions.first,
			serverAddressByClientCIDRs: nil,
			versions: groupVersions
		)

		let allGroups = [legacyAPIGroup] + apiGroupList.groups
		return meta.v1.APIGroupList(groups: allGroups)
	}

	func serverResources() async throws -> [meta.v1.APIResourceList] {
		let groupList = try await serverGroups()

		var allResourceLists = [meta.v1.APIResourceList]()
		for version in groupList.groups.flatMap(\.versions) {
			let it = try await serverResources(forGroupVersion: version.groupVersion)
			allResourceLists.append(it)
		}

		let merged = allResourceLists.reduce(into: [meta.v1.APIResourceList]()) { (acc, other: meta.v1.APIResourceList) in
			acc.append(other)
		}

		return merged
	}

	func serverResources(forGroupVersion groupVersion: String) async throws -> meta.v1.APIResourceList {
		let path: String
		if groupVersion == "v1" {
			path = "/api/v1"
		} else {
			path = "/apis/\(groupVersion)"
		}

		let request = try makeRequest().path(path).build()

		return try await dispatch(request: request, expect: meta.v1.APIResourceList.self)
	}

	func makeRequest() -> DiscoveryRequestBuilder {
		DiscoveryRequestBuilder(config: config)
	}
}
