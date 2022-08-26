// swift-tools-version: 5.6

import PackageDescription

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
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "CRDT",
            dependencies: []
        ),
        .testTarget(
            name: "CRDTTests",
            dependencies: ["CRDT"]
        ),
    ]
)
