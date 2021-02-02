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
import Foundation
import Logging

// MARK: - LogWatcher

final internal class LogWatcher: Watcher {

	private let delegate: LogWatcherDelegate

	init(delegate: LogWatcherDelegate) {
		self.delegate = delegate
	}

	func onError(error: SwiftkubeClientError) {
		delegate.onError(error: error)
	}

	public func onNext(payload: Data) {
		guard let string = String(data: payload, encoding: .utf8) else {
			delegate.onError(error: .decodingError("Could not deserialize payload"))
			return
		}

		string.enumerateLines { line, _ in
			self.delegate.onNext(line: line)
		}
	}
}

// MARK: - LogWatcherDelegate

public protocol LogWatcherDelegate {

	func onNext(line: String)
	func onError(error: SwiftkubeClientError)
}

// MARK: - LogWatcherCallback

open class LogWatcherCallback: LogWatcherDelegate {

	public typealias ErrorHandler = (SwiftkubeClientError) -> Void
	public typealias LineHandler = (String) -> Void

	private let errorHandler: ErrorHandler?
	private let lineHandler: LineHandler

	public init(
		onError errorHandler: ErrorHandler? = nil,
		onNext lineHandler: @escaping LineHandler
	) {
		self.errorHandler = errorHandler
		self.lineHandler = lineHandler
	}

	public func onError(error: SwiftkubeClientError) {
		errorHandler?(error)
	}

	public func onNext(line: String) {
		lineHandler(line)
	}
}
