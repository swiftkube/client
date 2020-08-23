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

import Foundation
import AsyncHTTPClient
import SwiftkubeModel

public final class DeploymentsHandler: NamespaceScopedResourceHandler {

	public typealias ResourceList = apps.v1.DeploymentList
	public typealias Resource = apps.v1.Deployment

	public let httpClient: HTTPClient
	public let config: KubernetesClientConfig
	public let context: ResourceHandlerContext

	public init(httpClient: HTTPClient, config: KubernetesClientConfig) {
		self.httpClient = httpClient
		self.config = config
		self.context = ResourceHandlerContext(
			apiGroupVersion: .appsV1,
			resoucePluralName: "deployments"
		)
	}
}
