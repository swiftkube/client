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

// MARK: IndexFunction

/// An alias for an Indexing Function, that can compute a list of indexed values for a given item.
public typealias IndexFuntion<Item> = (Item) throws -> [String]

// MARK: Index

/// An alias for an Index, which maps the indexed value to a set of keys in the store that match on that value.
public typealias Index = [String: Set<String>]

// MARK: - Indexer

/// Indexer extends Store with multiple indices and restricts each
/// accumulator to simply hold the current object (and be empty after
/// Delete).
///
/// There are three kinds of strings here:
///  1. a storage key, as defined in the Store interface,
///  2. a name of an index, and
///  3. an "indexed value", which is produced by an IndexFunc and
///     can be a field value or any other string computed from the object.
protocol Indexer: Store {

	associatedtype Item

	/// Retrieve list of stored obejcts matching the given object for the given named index.
	///
	/// - Parameters:
	///    - indexName: The name of the index used
	///    - item: The object to match against
	func index(indexName: String, item: Item) throws -> [Item]

	/// Retrieve list of stored keys matching the given indexed value for the given named index.
	///
	/// - Parameters:
	///    - indexName: The name of the index used
	///    - item: The indexed value to match against
	func indexKeys(indexName: String, indexedValue: String) -> [String]

	/// Retrieve list of stored objects matching the given indexed value for the given named index.
	///
	/// - Parameters:
	///    - indexName: The name of the index used
	///    - item: The indexed value to match against
	func byIndex(indexName: String, indexedValue: String) throws -> [Item]

	/// Returns a list of all `Indexers` registered with the `Store`.
	func getIndexers() -> [String: IndexFuntion<Item>]

	/// Add additional `Indexers` to the `Store`.
	func addIndexers(_ indexers: [String: IndexFuntion<Item>])
}
