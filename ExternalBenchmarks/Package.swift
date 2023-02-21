// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExternalBenchmarks",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "0.8.0")),
        .package(path: "../")
    ],
    targets: [
        .executableTarget(
            name: "ExternalBenchmarks",
            dependencies: [
                "CRDT",
                .product(name: "BenchmarkSupport", package: "package-benchmark")
            ],
            path: "Benchmarks/ExternalBenchmarks"),
    ]
)

