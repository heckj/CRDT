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
        .executable(name: "crdt-benchmark", targets: ["crdt-benchmark"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections-benchmark", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "CRDT",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=complete"]),
                /*
                    Summation from https://www.donnywals.com/enabling-concurrency-warnings-in-xcode-14/
                    Set `strict-concurrency` to `targeted` to enforce Sendable and actor-isolation checks in your code.
                      This explicitly verifies that `Sendable` constraints are met when you mark one of your types as `Sendable`.
                      This mode is essentially a bit of a hybrid between the behavior that's intended in Swift 6, and the default in Swift 5.7.
                      Use this mode to have a bit of checking on your code that uses Swift concurrency without too many warnings and / or errors in your current codebase.

                    Set `strict-concurrency` to `complete` to get the full suite of concurrency constraints, essentially as they will work in Swift 6.
                    */
            ]
        ),
        .testTarget(
            name: "CRDTTests",
            dependencies: ["CRDT"]
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
// use: swift build -Xswiftc -Xfrontend -Xswiftc -warn-concurrency
// to run with strict concurrency checking
