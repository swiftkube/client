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
import SwiftkubeModel

// MARK: - CacheError

/// Errors, that can be thrown when using the ``Cache`` with the default ``IndexFuntion`` and ``KeyFuntion``
public enum CacheError: Error {
	/// Thrown, when the passed object can't be indexed or a key can't be extracted.
	case invalidObject
}

// MARK: - Cache

/// A thread-safe `Store` imeplementation supporting `Indexing`
public class Cache<Item>: Indexer {

	private let keyFunction: KeyFuntion<Item>

	private var indexers: [String: IndexFuntion<Item>] = [:]

	private var indices: [String: Index] = [:]

	private var items: [String: Item] = [:]

	private var mutex = pthread_mutex_t()

	/// Constructs an instance with the default `namespace` index.
	///
	/// The default `namespace` index tries to extract the namespace from the ObjectMeta and it supports
	/// ``MetadataHavingResource`` and ``Dictionary<String, Any>``
	///
	/// The key is constructed from the resource `namesapce` and `name`: `<namespace>/<name>`
	convenience init() {
		self.init(
			indexName: "namespace",
			indexFunction: ObjectMetaNamespaceIndexFunction,
			keyFunction: ObjectMetaNamespaceKeyFunction
		)
	}

	/// Constructs an instance with the given index and key functions.
	///
	/// - Parameters:
	///    - indexName: The name for the index function.
	///    - indexFunction: An ``IndexFuntion`` to use for this cache instance.
	///    - keyFunction: A ``KeyFuntion`` to use for this cache instance.
	public init(
		indexName: String = "namespace",
		indexFunction: @escaping IndexFuntion<Item>,
		keyFunction: @escaping KeyFuntion<Item>
	) {
		indexers[indexName] = indexFunction
		self.keyFunction = keyFunction

		var attr = pthread_mutexattr_t()
		guard pthread_mutexattr_init(&attr) == 0 else {
			preconditionFailure()
		}

		pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
		guard pthread_mutex_init(&mutex, &attr) == 0 else {
			preconditionFailure()
		}

		pthread_mutexattr_destroy(&attr)
	}

	public func add(_ item: Item) throws {
		try update(item)
	}

	public func update(_ item: Item) throws {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		let key = try keyFunction(item)
		let oldItem = items[key]
		items[key] = item
		try updateIndices(oldItem: oldItem, newItem: item, key: key)
	}

	public func delete(_ item: Item) throws {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		let key = try keyFunction(item)
		let item = items[key]
		if item != nil {
			try updateIndices(oldItem: item, newItem: nil, key: key)
			items[key] = nil
		}
	}

	public func list() -> [Item] {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		return Array(items.values)
	}

	public func listKeys() -> [String] {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		return Array(items.keys)
	}

	public func get(_ item: Item) throws -> Item? {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		let key = try keyFunction(item)
		return get(byKey: key)
	}

	public func get(byKey: String) -> Item? {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		return items[byKey]
	}

	public func replace(with newItems: [Item], resourceVersion: String) throws {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		items = [:]
		try newItems.forEach { item in
			let key = try keyFunction(item)
			items[key] = item
		}

		try items.forEach { key, item in
			try updateIndices(oldItem: nil, newItem: item, key: key)
		}
	}

	public func resync() {
		// NOOP
	}

	public func index(indexName: String, item: Item) throws -> [Item] {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		guard let indexFunction = indexers[indexName], let index = indices[indexName] else {
			return []
		}

		if index.isEmpty {
			return []
		}

		let indexValues = try indexFunction(item)

		let allValues = indexValues
			.compactMap { index[$0] }
			.flatMap { $0 }

		let uniqueValues = Set(allValues)

		return uniqueValues.compactMap { value in
			items[value]
		}
	}

	public func indexKeys(indexName: String, indexedValue: String) -> [String] {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		guard let _ = indexers[indexName], let index = indices[indexName] else {
			return []
		}

		let set = index[indexedValue]

		return Array(set ?? [])
	}

	public func byIndex(indexName: String, indexedValue: String) -> [Item] {
		pthread_mutex_lock(&mutex)
		defer { pthread_mutex_unlock(&mutex) }

		guard let _ = indexers[indexName], let index = indices[indexName] else {
			return []
		}

		let set = index[indexedValue] ?? []

		return set.compactMap { value in
			items[value]
		}
	}

	public func getIndexers() -> [String: IndexFuntion<Item>] {
		indexers
	}

	public func addIndexers(_ newIndexes: [String: IndexFuntion<Item>]) {
		newIndexes.forEach { indexName, indexFuntion in
			indices[indexName] = Index()
			indexers[indexName] = indexFuntion
		}
	}

	private func updateIndices(oldItem: Item?, newItem: Item?, key: String) throws {
		try indexers.forEach { indexName, indexFunction in
			let oldIndexValues = oldItem != nil ? try indexFunction(oldItem!) : []
			let newIndexValues = newItem != nil ? try indexFunction(newItem!) : []

			if newIndexValues.count == 1 && oldIndexValues.count == 1 && newIndexValues.first! == oldIndexValues.first! {
				return
			}

			var index = indices[indexName]
			if index == nil {
				index = Index()
			}

			oldIndexValues.forEach { value in
				guard var set = index?[value] else {
					return
				}

				set.remove(key)

				if set.count == 0 {
					index?[value] = nil
				} else {
					index?[value] = set
				}
			}

			newIndexValues.forEach { value in
				var set = index?[value]
				if set == nil {
					set = Set<String>()
				}

				set?.insert(key)

				index?[value] = set
			}

			indices[indexName] = index
		}
	}
}
