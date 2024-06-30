// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SwiftkubeClient",
	platforms: [
		.macOS(.v10_15), .iOS(.v14), .tvOS(.v14), .watchOS(.v7),
	],
	products: [
		.library(
			name: "SwiftkubeClient",
			targets: ["SwiftkubeClient"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/swiftkube/model.git", .upToNextMinor(from: "0.14.0")),
		.package(url: "https://github.com/swift-server/async-http-client.git", .upToNextMajor(from: "1.21.2")),
		.package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.6.1")),
		.package(url: "https://github.com/apple/swift-metrics.git", .upToNextMajor(from: "2.5.0")),
		.package(url: "https://github.com/jpsim/Yams.git", .upToNextMajor(from: "5.1.2")),
		.package(url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.67.0")),
	],
	targets: [
		.target(
			name: "SwiftkubeClient",
			dependencies: [
				.product(name: "SwiftkubeModel", package: "model"),
				.product(name: "AsyncHTTPClient", package: "async-http-client"),
				.product(name: "Logging", package: "swift-log"),
				.product(name: "Metrics", package: "swift-metrics"),
				.product(name: "Yams", package: "Yams"),
				.product(name: "NIO", package: "swift-nio"),
				.product(name: "NIOFoundationCompat", package: "swift-nio"),
			]
		),
		.testTarget(
			name: "SwiftkubeClientTests",
			dependencies: [
				"SwiftkubeClient",
			]
		),
	]
)
