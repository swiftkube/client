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

// MARK: - RetryAttempt

/// Describes a retry attempt by specifying the attempts number and its delay in seconds.
public struct RetryAttempt: Hashable {
	public let attempt: UInt
	public let delay: TimeInterval
}

// MARK: - RetryStrategy

/// A RetryStrategy defines how client requests should be retried when encountering non-recoverable errors.
/// Basically it is a sequence of RetryAttempts generated according to a Policy and Backoff definition.
public struct RetryStrategy: Sequence {

	public typealias Iterator = RetryAttemptIterator

	public static var never: RetryStrategy {
		RetryStrategy(policy: .never, backoff: .none, initialDelay: 0.0, jitter: 0.0)
	}

	/// The retry policy for a given strategy.
	public enum Policy {
		/// Always retries.
		case always
		/// Never retries.
		case never
		/// Retries a maximum of given times before giving up.
		case maxAttempts(Int)

		internal func shouldRetry(currentAttempt: UInt) -> Bool {
			switch self {
			case .never:
				return false
			case .always:
				return true
			case let .maxAttempts(attempts):
				return currentAttempt <= attempts
			}
		}
	}

	/// Defines the backoff behaviour between each retry attempt.
	public enum Backoff {
		/// No backoff.
		case none
		/// A fixed delay between each attempt specified in seconds.
		case fixedDelay(TimeInterval)
		/// An exponential backoff. The delay between each attempt is the minimum of the current delay multiplied by the given `multiplier`
		/// or the specified `maximumDelay`.
		case exponential(maximumDelay: TimeInterval, multiplier: Double)

		internal func computeNext(currentDelay: TimeInterval) -> TimeInterval {
			switch self {
			case .none:
				return 0.0
			case let .fixedDelay(delay):
				return currentDelay + delay
			case let .exponential(maximumDelay: max, multiplier: multiplier):
				let next = currentDelay * multiplier
				return Swift.min(next, max)
			}
		}
	}

	/// The initial delay before the first retry attempt.
	public let initialDelay: TimeInterval

	/// A jitter value that is applied to each computed delay to prevent congestion.
	public let jitter: Double

	/// A retry policy.
	public let policy: Policy

	/// Backoff definition.
	public let backoff: Backoff

	/// Creates RetryStrategy based on the provided values.
	///
	/// - Parameters:
	///   - policy: The policy to apply.
	///   - backoff: The backoff definition to use.
	///   - initialDelay: The initial delay before the first retry attempt.
	///   - jitter: The jitter value to apply on each delay.
	public init(
		policy: Policy = .maxAttempts(10),
		backoff: Backoff = .fixedDelay(5.0),
		initialDelay: TimeInterval = 1.0,
		jitter: Double = 0.2
	) {
		self.initialDelay = initialDelay
		self.jitter = jitter
		self.policy = policy
		self.backoff = backoff
	}

	public func makeIterator() -> RetryAttemptIterator {
		RetryAttemptIterator(strategy: self)
	}
}

// MARK: - RetryAttemptIterator

public class RetryAttemptIterator: IteratorProtocol {

	public typealias Element = RetryAttempt

	public let strategy: RetryStrategy
	private var currentAttempt: UInt = 1
	private var currentDelay: TimeInterval

	init(strategy: RetryStrategy) {
		self.strategy = strategy
		self.currentDelay = strategy.initialDelay
	}

	public func next() -> RetryAttempt? {
		guard strategy.policy.shouldRetry(currentAttempt: currentAttempt) else {
			return nil
		}

		if currentAttempt == 1 {
			currentAttempt += 1
			return RetryAttempt(attempt: 1, delay: strategy.initialDelay)
		}

		let nextDelay = strategy.backoff.computeNext(currentDelay: currentDelay)
		let nextJitter = add(jitter: strategy.jitter, to: nextDelay)

		defer {
			currentAttempt += 1
			currentDelay = nextDelay
		}

		return RetryAttempt(attempt: currentAttempt, delay: nextJitter)
	}

	private func add(jitter: Double, to delay: TimeInterval) -> TimeInterval {
		let jitterBound = jitter * delay
		let randomJitter = TimeInterval.random(in: -jitterBound ... jitterBound)
		return delay + randomJitter
	}
}
