// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "TrinketCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
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
            resources: [.process("Resources")],
        ),
        .testTarget(
            name: "TrinketCoreTests",
            dependencies: ["TrinketCore"],
        ),
    ],
)
