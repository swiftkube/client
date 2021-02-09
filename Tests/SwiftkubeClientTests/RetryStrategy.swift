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
@testable import SwiftkubeClient
import XCTest

final class RetryStrategyTests: XCTestCase {

	func testAlwaysPolicy() {
		let policy: RetryStrategy.Policy = .always
		XCTAssertTrue(policy.shouldRetry(currentAttempt: 0))
		XCTAssertTrue(policy.shouldRetry(currentAttempt: 42))
		XCTAssertTrue(policy.shouldRetry(currentAttempt: UInt.max))
	}

	func testNeverPolicy() {
		let policy: RetryStrategy.Policy = .never
		XCTAssertFalse(policy.shouldRetry(currentAttempt: 0))
		XCTAssertFalse(policy.shouldRetry(currentAttempt: 42))
		XCTAssertFalse(policy.shouldRetry(currentAttempt: UInt.max))
	}

	func testMaxAttemptsPolicy() {
		let policy: RetryStrategy.Policy = .maxAttemtps(10)
		XCTAssertTrue(policy.shouldRetry(currentAttempt: 0))
		XCTAssertTrue(policy.shouldRetry(currentAttempt: 9))
		XCTAssertTrue(policy.shouldRetry(currentAttempt: 10))
		XCTAssertFalse(policy.shouldRetry(currentAttempt: 11))
		XCTAssertFalse(policy.shouldRetry(currentAttempt: UInt.max))
	}

	func testNoneBackoff() {
		let backoff: RetryStrategy.Backoff = .none
		XCTAssertEqual(backoff.computeNext(currentDelay: 0), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 10), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 0), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 10), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 0), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 10), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: Double.Magnitude.greatestFiniteMagnitude), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: Double.Magnitude.greatestFiniteMagnitude), 0.0)
	}

	func testFixedDelayBackoff() {
		let backoff: RetryStrategy.Backoff = .fixedDelay(10)
		XCTAssertEqual(backoff.computeNext(currentDelay: 0), 10.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 10), 20.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 20), 30.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 30), 40.0)
	}

	func testExponentialBackoff() {
		let backoff: RetryStrategy.Backoff = .exponential(maximumDelay: 60, multiplier: 2.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 0), 0.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 10), 20.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 20), 40.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 30), 60.0)
		XCTAssertEqual(backoff.computeNext(currentDelay: 40), 60.0)
	}

	func testNeverSequence() {
		let strategy = RetryStrategy(policy: .never, backoff: .fixedDelay(10), initialDelay: 0.0, jitter: 0.0)
		let attempts = Array(strategy)

		XCTAssertTrue(attempts.isEmpty)
	}

	func testMaxAttemptSequenceWithNoBackoff() {
		let strategy = RetryStrategy(policy: .maxAttemtps(3), backoff: .none, initialDelay: 0.0, jitter: 0.0)
		let attempts = Array(strategy)

		XCTAssertEqual(attempts, [
			RetryAttempt(attempt: 1, delay: 0.0),
			RetryAttempt(attempt: 2, delay: 0.0),
			RetryAttempt(attempt: 3, delay: 0.0)
		])
	}

	func testMaxAttemptSequenceWithFixedDelay() {
		let strategy = RetryStrategy(policy: .maxAttemtps(3), backoff: .fixedDelay(10), initialDelay: 10.0, jitter: 0.0)
		let attempts = Array(strategy)

		XCTAssertEqual(attempts, [
			RetryAttempt(attempt: 1, delay: 10.0),
			RetryAttempt(attempt: 2, delay: 20.0),
			RetryAttempt(attempt: 3, delay: 30.0)
		])
	}

	func testMaxAttemptSequenceWithExponentialBackoff() {
		let strategy = RetryStrategy(policy: .maxAttemtps(3), backoff: .exponential(maximumDelay: 80, multiplier: 2), initialDelay: 0.0, jitter: 0.0)
		let attempts = Array(strategy)

		XCTAssertEqual(attempts, [
			RetryAttempt(attempt: 1, delay: 0.0),
			RetryAttempt(attempt: 2, delay: 0.0),
			RetryAttempt(attempt: 3, delay: 0.0)
		])
	}

	func testBackoffSequence() {
		let strategy = RetryStrategy(policy: .maxAttemtps(5), backoff: .exponential(maximumDelay: 80, multiplier: 2), initialDelay: 10.0, jitter: 0.0)
		let attempts = Array(strategy)

		XCTAssertEqual(attempts, [
			RetryAttempt(attempt: 1, delay: 10.0),
			RetryAttempt(attempt: 2, delay: 20.0),
			RetryAttempt(attempt: 3, delay: 40.0),
			RetryAttempt(attempt: 4, delay: 80.0),
			RetryAttempt(attempt: 5, delay: 80.0),
		])
	}
}
