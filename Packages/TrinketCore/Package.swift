// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TrinketCore",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "TrinketCore",
            targets: ["TrinketCore"]
        ),
    ],
    targets: [
        .target(
            name: "TrinketCore",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=off"]),
            ]
        ),
        .testTarget(
            name: "TrinketCoreTests",
            dependencies: ["TrinketCore"]
        ),
    ]
)
