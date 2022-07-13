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

/// GenerateRandomHash returns a three character. I
func GenerateRandomHash() -> String {
	// We omit vowels from the set of available characters to reduce the chances
	// of "bad words" being formed.
	let alphanums = ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "w", "x", "z", "2", "4", "5", "6", "7", "8", "9"]
	var seedAlphanum = alphanums.randomElement()!
	var slug = seedAlphanum
	var neededAlphanums = 2
	while neededAlphanums > 0 {
		let nextAlphanum = alphanums.randomElement()!
		if nextAlphanum != seedAlphanum {
			seedAlphanum = nextAlphanum
			slug = slug + nextAlphanum
			neededAlphanums -= 1
		}
	}
	return slug
}
