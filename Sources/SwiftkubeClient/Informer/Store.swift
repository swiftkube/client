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

/// An alias for an Key Function, that can compute a key for a given item.
public typealias KeyFuntion<Item> = (Item) throws -> String

// MARK: - Store

/// Store is a generic object storage and processing interface.  A
/// Store holds a map from string keys to accumulators, and has
/// operations to add, update, and delete a given object to/from the
/// accumulator currently associated with a given key.  A Store also
/// knows how to extract the key from a given object, so many operations
/// are given only the object.
///
/// In the simplest Store implementations each accumulator is simply
/// the last given object, or empty after Delete, and thus the Store's
/// behavior is simple storage.
///
/// Reflector knows how to watch a server and update a Store.
public protocol Store<Item> {

	associatedtype Item

	/// Add adds the given object to the accumulator associated with the given object's key
	func add(_ item: Item) throws

	/// Update updates the given object in the accumulator associated with the given object's key
	func update(_ item: Item) throws

	/// Deletes the given object from the accumulator associated with the given object's key
	func delete(_ item: Item) throws

	/// Returns a list of all the currently non-empty accumulators
	func list() -> [Item]

	/// Returns a list of all the keys currently associated with non-empty accumulators
	func listKeys() -> [String]

	/// Returns the accumulator associated with the given object's key
	func get(_ item: Item) throws -> Item?

	/// Returns the accumulator associated with the given key
	func get(byKey: String) -> Item?

	/// Replace the contents of the store, using instead the given list.
	func replace(with: [Item], resourceVersion: String) throws

	/// Sends a `resync` event for each item.
	func resync()
}
