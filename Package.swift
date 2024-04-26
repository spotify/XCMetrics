// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XCMetrics",
    platforms: [
        .macOS(.v13),
    ], products: [
        .executable(name: "XCMetrics", targets: ["XCMetricsApp"]),
        .executable(name: "XCMetricsBackend", targets: ["XCMetricsBackend"]),
        .library(name: "XCMetricsBackendLib", targets: ["XCMetricsBackendLib"]),
        .library(name: "XCMetricsClient", targets: ["XCMetricsClient"]),
        .library(name: "XCMetricsPlugins", targets: ["XCMetricsPlugins"]),
        .library(name: "XCMetricsUtils", targets: ["XCMetricsUtils"]),
    ],
    dependencies: [
        .package(url: "https://github.com/MobileNativeFoundation/XCLogParser", from: "0.2.39"),
        .package(url: "https://github.com/apple/swift-tools-support-core.git", exact: "0.2.7"),
        .package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.0.0-alpha.9"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.32.3"),
        .package(url: "https://github.com/apple/swift-nio-http2.git", from: "1.15.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", .upToNextMajor(from: "2.10.0")),
        .package(url: "https://github.com/Spotify/Mobius.swift", exact: "0.3.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "3.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0"),
        .package(url: "https://github.com/vapor/vapor.git", from: "4.65.2"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.5.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.4.0"),
        .package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0"),
        .package(url: "https://github.com/vapor/queues.git", from: "1.5.1"),
        .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor-community/google-cloud-kit.git", from: "1.0.0-rc.2"),
        .package(url: "https://github.com/soto-project/soto.git", from: "4.0.0"),
    ],
    targets: [
        .target(
            name: "XCMetricsClient",
            dependencies: [
                "XCMetricsProto",
                "XCMetricsUtils",
                "XCMetricsCommon",
                .product(name: "XCLogParser", package: "XCLogParser"),
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2"),
                .product(name: "MobiusCore", package: "Mobius.swift"),
                .product(name: "MobiusExtras", package: "Mobius.swift"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "Yams", package: "Yams"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "XCMetricsPlugins",
            dependencies: [
                "XCMetricsClient",
                "XCMetricsUtils",
                .product(name: "CryptoSwift", package: "CryptoSwift"),
            ]
        ),
        .target(
            name: "XCMetricsUtils",
            dependencies: []
        ),
        .target(
            name: "XCMetricsProto",
            dependencies: [
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP2", package: "swift-nio-http2")
            ]
        ),
        .target(
            name: "XCMetricsApp",
            dependencies: ["XCMetricsClient"]
        ),
        .target(
            name: "XCMetricsCommon",
            dependencies: []
        ),
       .target(
            name: "XCMetricsBackendLib",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Queues", package: "queues"),
                .product(name: "QueuesRedisDriver", package: "queues-redis-driver"),
                .product(name: "Redis", package: "redis"),
                .product(name: "XCLogParser", package: "XCLogParser"),
                .product(name: "CryptoSwift", package: "CryptoSwift"),
                .product(name: "GoogleCloudKit", package: "google-cloud-kit"),
                .product(name: "S3", package: "soto"),
                "XCMetricsCommon"
            ],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .target(name: "XCMetricsBackend", dependencies: [.target(name: "XCMetricsBackendLib")]),
        .testTarget(
            name: "XCMetricsTests",
            dependencies: [
                "XCMetricsClient",
                "XCMetricsProto",
                .product(name: "MobiusTest", package: "Mobius.swift"),
                .product(name: "SwiftToolsSupport", package: "swift-tools-support-core"),
            ]
        ),
        .testTarget(
            name: "XCMetricsPluginsTests",
            dependencies: ["XCMetricsPlugins"]
        ),
        .testTarget(name: "XCMetricsBackendLibTests", dependencies: [
            .target(name: "XCMetricsBackendLib"),
            .product(name: "XCTVapor", package: "vapor"),
            .product(name: "XCTQueues", package: "queues")
        ]),
    ]
)
