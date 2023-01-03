// swift-tools-version:5.5
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
		.package(name: "SwiftkubeModel", url: "https://github.com/swiftkube/model.git", .upToNextMinor(from: "0.6.0")),
		.package(name: "async-http-client", url: "https://github.com/swift-server/async-http-client.git", .upToNextMajor(from: "1.13.1")),
		.package(name: "swift-log", url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.4.4")),
		.package(name: "swift-metrics", url: "https://github.com/apple/swift-metrics.git", .upToNextMajor(from: "2.3.3")),
		.package(name: "Yams", url: "https://github.com/jpsim/Yams.git", .upToNextMajor(from: "5.0.1")),
		.package(name: "swift-nio", url: "https://github.com/apple/swift-nio", .upToNextMajor(from: "2.46.0")),
	],
	targets: [
		.target(
			name: "SwiftkubeClient",
			dependencies: [
				.product(name: "SwiftkubeModel", package: "SwiftkubeModel"),
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
