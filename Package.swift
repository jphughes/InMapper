// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InMapper",
	platforms: [
		.macOS(.v14),
		.iOS(.v16)
	],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "InMapper",
            targets: ["InMapper"]),
    ],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.5.4"),
		.package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0")
	],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "InMapper",
			dependencies: [
				.product(name: "Logging", package: "swift-log"),
				.product(name: "AsyncHTTPClient", package: "async-http-client")]
		),
        .testTarget(
            name: "InMapperTests",
            dependencies: ["InMapper"]),
    ]
)
