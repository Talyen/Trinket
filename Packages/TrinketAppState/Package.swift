// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketAppState",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "TrinketAppState",
            targets: ["TrinketAppState"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../BattleEngine"),
        .package(path: "../TrinketPersistence"),
        // No source-level imports, but required at link time: TrinketBattleFeature
        // public initializers use TrinketDesignSystem values as default arguments,
        // which Swift emits into this (calling) module.
        .package(path: "../TrinketDesignSystem"),
        .package(path: "../TrinketFeatureSupport"),
        .package(path: "../TrinketBattleFeature"),
        .package(path: "../TrinketTestSupport"),
    ],
    targets: [
        .target(
            name: "TrinketAppState",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketPersistence",
                "TrinketDesignSystem",
                "TrinketFeatureSupport",
                .product(name: "TrinketFeatureAdapters", package: "TrinketFeatureSupport"),
                "TrinketBattleFeature",
            ]
        ),
        .testTarget(
            name: "TrinketAppStateTests",
            dependencies: [
                "TrinketAppState",
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketPersistence",
                "TrinketFeatureSupport",
                .product(name: "TrinketFeatureAdapters", package: "TrinketFeatureSupport"),
                "TrinketBattleFeature",
                .product(name: "TrinketTestSupport", package: "TrinketTestSupport"),
            ]
        ),
    ]
)
