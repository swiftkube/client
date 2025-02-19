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

import SwiftkubeClient
import SwiftkubeModel
import XCTest

final class K8sCRDTests: K8sTestCase {

	private let cocktailCRD = apiextensions.v1.CustomResourceDefinition(
		metadata: meta.v1.ObjectMeta(name: "cocktails.example.swiftkube.dev"),
		spec: apiextensions.v1.CustomResourceDefinitionSpec(
			group: "example.swiftkube.dev",
			names: apiextensions.v1.CustomResourceDefinitionNames(
				kind: "Cocktail",
				plural: "cocktails",
				singular: "cocktail"
			),
			scope: "Namespaced",
			versions: [
				apiextensions.v1.CustomResourceDefinitionVersion(
					name: "v1",
					schema: apiextensions.v1.CustomResourceValidation(
						openAPIV3Schema: JSONObject(properties: [
							"type": "object",
							"x-kubernetes-preserve-unknown-fields": true,
							"properties": [
								"apiVersion": ["type": "string"],
								"kind": ["type": "string"],
								"metadata": [
									"type": "object"
								],
								"spec": [
									"type": "object",
									"properties": [
										"name": ["type": "string"],
										"ingredients": [
											"type": "array",
											"items": ["type": "string"]
										] as [String: Sendable]
									] as [String: Sendable]
								] as [String: Sendable]
							] as [String: Sendable]
						])
					),
					served: true,
					storage: true
				)
			]
		)
	)

	struct CocktailList: KubernetesResourceList {
		typealias Item = Cocktail

		var apiVersion = "example.swiftkube.dev/v1"
		var kind = "Cocktails"
		var metadata: SwiftkubeModel.meta.v1.ListMeta?
		var items: [K3dCRDTests.Cocktail]
	}

	struct Cocktail: KubernetesAPIResource, NamespacedResource,
		MetadataHavingResource, ReadableResource, CreatableResource, ListableResource {

		typealias List = CocktailList

		var apiVersion = "example.swiftkube.dev/v1"
		var kind = "Cocktail"
		var metadata: meta.v1.ObjectMeta?
		var spec: CocktailSpec
	}

	struct CocktailSpec: Codable, Hashable {
		var name: String
		var ingredients: [String]
	}

	override class func setUp() {
		super.setUp()

		// ensure clean state
		deleteNamespace("crd-test")

		// create namespaces for tests
		createNamespace("crd-test")
	}

	func testCRD() async {
		let _ = try? await K8sTestCase.client.apiExtensionsV1.customResourceDefinitions.create(cocktailCRD)

		let allCRDs = try? await K8sTestCase.client.apiExtensionsV1.customResourceDefinitions.list()

		let cocktail = allCRDs?.first { element in
			element.spec.names.kind == "Cocktail"
		}
		XCTAssertNotNil(cocktail)

		let gvr = GroupVersionResource(
			group: "example.swiftkube.dev",
			version: "v1",
			resource: "cocktails"
		)

		let cocktailsClient = K8sTestCase.client.for(Cocktail.self, gvr: gvr)

		try? _ = await cocktailsClient.create(in: .namespace("crd-test"), Cocktail(
			metadata: meta.v1.ObjectMeta(name: "gin-tonic"),
			spec: CocktailSpec(
				name: "Basic Gin Tonic",
				ingredients: ["Gin", "Tonic"]
			))
		)

		try? _ = await cocktailsClient.create(in: .namespace("crd-test"), Cocktail(
			metadata: meta.v1.ObjectMeta(name: "cuba-libre"),
			spec: CocktailSpec(
				name: "Cuba Libre",
				ingredients: ["Rum", "Cola"]
			))
		)

		let cocktails = try? await cocktailsClient.list(in: .namespace("crd-test"))
		let shoppingList = cocktails?.items.flatMap {
			$0.spec.ingredients
		}

		assertEqual(shoppingList, ["Gin", "Tonic", "Cola", "Rum"])
	}
}
