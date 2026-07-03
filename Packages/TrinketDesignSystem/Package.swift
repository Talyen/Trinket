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
        .package(path: "../TrinketContent"),
    ],
    targets: [
        .target(
            name: "TrinketDesignSystem",
            dependencies: ["TrinketCore", "TrinketContent"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=off"]),
            ]
        ),
        .testTarget(
            name: "TrinketDesignSystemTests",
            dependencies: ["TrinketDesignSystem", "TrinketCore"]
        ),
    ]
)
