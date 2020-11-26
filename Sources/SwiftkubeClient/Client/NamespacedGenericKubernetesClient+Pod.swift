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
import NIO
import SwiftkubeModel

public extension NamespacedGenericKubernetesClient where Resource == core.v1.Pod {

	func follow(in namespace: NamespaceSelector? = nil, name: String, container: String?, lineHandler: @escaping LogWatch.LineHandler) throws -> HTTPClient.Task<Void> {
		return try super.follow(in: namespace ?? .namespace(self.config.namespace), name: name, container: container, using: LogWatch(logger: logger, lineHandler))
	}

	func status(in namespace: NamespaceSelector? = nil, name: String) throws -> EventLoopFuture<core.v1.Pod> {
		return try super.status(in: namespace ?? .namespace(self.config.namespace), name: name)
	}

	func updateStatus(in namespace: NamespaceSelector? = nil, _ pod: core.v1.Pod) throws -> EventLoopFuture<core.v1.Pod> {
		return try super.updateStatus(in: namespace ?? .namespace(self.config.namespace), pod)
	}
}
