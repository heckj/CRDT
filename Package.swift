// swift-tools-version: 5.8

import PackageDescription

var globalSwiftSettings: [PackageDescription.SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "CRDT",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    products: [
        .library(
            name: "CRDT",
            targets: ["CRDT"]
        ),
        .executable(name: "crdt-benchmark", targets: ["crdt-benchmark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections-benchmark", from: "0.0.1"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
    ],
    targets: [
        .target(
            name: "CRDT",
            dependencies: [.product(name: "SwiftProtobuf", package: "swift-protobuf")],
            swiftSettings: globalSwiftSettings
        ),
        .testTarget(
            name: "CRDTTests",
            dependencies: ["CRDT", .product(name: "SwiftProtobuf", package: "swift-protobuf")]
        ),
        .executableTarget(
            name: "crdt-benchmark",
            dependencies: [
                "CRDT",
                .product(name: "CollectionsBenchmark", package: "swift-collections-benchmark"),
            ]
        ),
    ]
)
