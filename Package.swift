// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required
// to build this package.

import PackageDescription

let flowpayUtilities: Target.Dependency = .product(name: "FlowpayUtilities", package: "services-utilities")
let fluent: Target.Dependency = .product(name: "Fluent", package: "fluent")
let mongodb: Target.Dependency = .product(name: "FluentMongoDriver", package: "fluent-mongo-driver")
let postgres: Target.Dependency = .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
let sqlite: Target.Dependency = .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver")
let vapor: Target.Dependency = .product(name: "Vapor", package: "vapor")
let queues: Target.Dependency = .product(name: "Queues", package: "queues")

let package = Package(
	name: "Microservice",
	platforms: [
		.macOS(.v13)
	],
	products: [
		.executable(name: "Run", targets: ["Run"])
	],
        dependencies: [
                .package(url: "git@github.com:FlowPay/services-utilities.git", branch: "v2"),
                .package(url: "https://github.com/vapor/fluent-mongo-driver.git", from: "1.3.0"),
                .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
                .package(url: "https://github.com/vapor/fluent-sqlite-driver.git", from: "4.0.0"),
                .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
                .package(url: "https://github.com/vapor/vapor.git", from: "4.27.3"),
                .package(url: "https://github.com/vapor/queues.git", from: "1.10.0"),
        ],
        targets: [
                .target(
                        name: "Core",
                        dependencies: [
                                flowpayUtilities,
                                fluent,
                                vapor,
                                queues,
                        ]
                ),
                .target(
                        name: "Api",
                        dependencies: [
                                .target(name: "Core"),
                                flowpayUtilities,
                                vapor,

                        ],
                        swiftSettings: [
                                .unsafeFlags(["-enable-bare-slash-regex"])
                        ]
                ),
                .target(
                        name: "App",
                        dependencies: [
                                .target(name: "Api"),
                                .target(name: "Core"),
                                flowpayUtilities,
                                fluent,
                                mongodb,
                                postgres,
                                sqlite,
                                vapor,
                                queues,
                        ]
                ),
                .executableTarget(
                        name: "Run",
                        dependencies: [
                                .target(name: "App"),
                                vapor,
                        ],
                        swiftSettings: [
                                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
                        ]
                ),
                .testTarget(
                        name: "AppTests",
                        dependencies: [
                                .product(name: "XCTVapor", package: "vapor"),
                                "Api",
                                "App",
                                "Core",
                        ],
                        resources: []
                ),
        ]
)
