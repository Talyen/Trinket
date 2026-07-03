// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TrinketDesignSystem",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "TrinketDesignSystem",
            targets: ["TrinketDesignSystem"]
        ),
    ],
    dependencies: [
        .package(path: "../BattleEngine"),
    ],
    targets: [
        .target(
            name: "TrinketDesignSystem",
            dependencies: ["BattleEngine"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=off"]),
            ]
        ),
    ]
)
