// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketBattleFeature",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "TrinketBattleFeature",
            targets: ["TrinketBattleFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../BattleEngine"),
        .package(path: "../TrinketPersistence"),
        .package(path: "../TrinketDesignSystem"),
        .package(path: "../TrinketFeatureSupport"),
        .package(path: "../TrinketTestSupport"),
    ],
    targets: [
        .target(
            name: "TrinketBattleFeature",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketPersistence",
                "TrinketDesignSystem",
                "TrinketFeatureSupport",
            ]
        ),
        .testTarget(
            name: "TrinketBattleFeatureTests",
            dependencies: [
                "TrinketBattleFeature",
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketPersistence",
                "TrinketDesignSystem",
                "TrinketFeatureSupport",
                "TrinketTestSupport",
            ]
        ),
    ]
)
