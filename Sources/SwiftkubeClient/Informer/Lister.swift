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

import Foundation

/// Lister is used to list cached objects from a running ``Informer``
public class Lister<Item> {

	private let namespace: NamespaceSelector
	private let indexName: String
	private let indexer: any Indexer<Item>

	///
	convenience init(indexer: any Indexer<Item>) {
		self.init(namespace: .allNamespaces, indexName: "namespace", indexer: indexer)
	}

	convenience init(namespace: NamespaceSelector, indexer: any Indexer<Item>) {
		self.init(namespace: namespace, indexName: "namespace", indexer: indexer)
	}

	/// Constructs an instance for the given namespace and ``Indexer``.
	///
	/// - Parameters:
	///    - namespace: Selects the namespace for this instance.
	///    - indexName: The name for the underlying index to use for this instance.
	///    - indexer: An ``Indexer`` imlpementation instance.
	public init(namespace: NamespaceSelector, indexName: String, indexer: any Indexer<Item>) {
		self.namespace = namespace
		self.indexName = indexName
		self.indexer = indexer
	}

	/// Lists the items from the backing indexer in the selected namespaces
	public func list() throws -> [Item] {
		if case NamespaceSelector.allNamespaces = namespace {
			return indexer.list()
		}

		return try indexer.byIndex(indexName: indexName, indexedValue: namespace.namespaceName())
	}

	/// Gets an object by it's name from the indexer
	public func get(byName name: String) throws -> Item? {
		var key = name
		if case NamespaceSelector.allNamespaces = namespace {
			key = "\(namespace.namespaceName())/\(name)"
		}

		return indexer.get(byKey: key)
	}

	/// Constructs a new ``Lister`` for the given namespace
	public func namespace(_ namespace: NamespaceSelector) -> Lister<Item> {
		Lister(namespace: namespace, indexName: "namespace", indexer: indexer)
	}
}
