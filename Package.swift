// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "SwiftkubeClient",
	platforms: [
		.macOS(.v10_13), .iOS(.v12), .tvOS(.v12), .watchOS(.v5),
	],
	products: [
		.library(
			name: "SwiftkubeClient",
			targets: ["SwiftkubeClient"]
		),
	],
	dependencies: [
		.package(name: "SwiftkubeModel", url: "https://github.com/swiftkube/model.git", .upToNextMajor(from: "0.4.0")),
		.package(name: "async-http-client", url: "https://github.com/swift-server/async-http-client.git", .upToNextMajor(from: "1.2.0")),
		.package(name: "swift-log", url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.4.0")),
		.package(name: "swift-metrics", url: "https://github.com/apple/swift-metrics.git", "1.0.0" ..< "3.0.0"),
		.package(name: "Yams", url: "https://github.com/jpsim/Yams.git", .upToNextMajor(from: "4.0.0")),
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
