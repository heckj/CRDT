// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "CRDT",
    products: [
        .library(
            name: "CRDT",
            targets: ["CRDT"]
        ),
    ],
    dependencies: [
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
