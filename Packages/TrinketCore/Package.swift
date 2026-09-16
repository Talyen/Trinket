// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketCore",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "TrinketCore",
            targets: ["TrinketCore"],
        ),
    ],
    targets: [
        .target(
            name: "TrinketCore",
        ),
        .testTarget(
            name: "TrinketCoreTests",
            dependencies: ["TrinketCore"],
        ),
    ],
)
