// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketDesignSystem",
    platforms: [
        .iOS(.v26),
    ],
    products: [
        .library(
            name: "TrinketDesignSystem",
            targets: ["TrinketDesignSystem"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
    ],
    targets: [
        .target(
            name: "TrinketDesignSystem",
            dependencies: ["TrinketCore"]
        ),
        .testTarget(
            name: "TrinketDesignSystemTests",
            dependencies: ["TrinketDesignSystem", "TrinketCore"]
        ),
    ]
)
