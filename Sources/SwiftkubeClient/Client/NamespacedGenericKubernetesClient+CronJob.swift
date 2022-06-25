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
import SwiftkubeModel

public extension NamespacedGenericKubernetesClient where Resource == batch.v1beta1.CronJob {

	func suspend(
		in namespace: NamespaceSelector,
		name: String
	) throws -> EventLoopFuture<Resource> {
		try super.suspend(in: namespace, name: name)
	}

	func unsuspend(
		in namespace: NamespaceSelector,
		name: String
	) throws -> EventLoopFuture<Resource> {
		try super.unsuspend(in: namespace, name: name)
	}
}
