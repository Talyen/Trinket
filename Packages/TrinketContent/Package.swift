// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketContent",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TrinketContent",
            targets: ["TrinketContent"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
    ],
    targets: [
        .target(
            name: "TrinketContent",
            dependencies: ["TrinketCore"]
        ),
        .testTarget(
            name: "TrinketContentTests",
            dependencies: ["TrinketContent"]
        ),
    ]
)
