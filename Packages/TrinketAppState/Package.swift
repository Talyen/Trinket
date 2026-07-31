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
        .package(path: "../TrinketBattleRuntime"),
        .package(path: "../TrinketPersistence"),
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
                "TrinketBattleRuntime",
                "TrinketPersistence",
                "TrinketDesignSystem",
                .product(name: "TrinketFeatureContracts", package: "TrinketFeatureSupport"),
            ]
        ),
        .testTarget(
            name: "TrinketAppStateTests",
            dependencies: [
                "TrinketAppState",
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketBattleRuntime",
                "TrinketPersistence",
                "TrinketFeatureSupport",
                .product(name: "TrinketFeatureContracts", package: "TrinketFeatureSupport"),
                .product(name: "TrinketFeatureAdapters", package: "TrinketFeatureSupport"),
                "TrinketBattleFeature",
                .product(name: "TrinketTestSupport", package: "TrinketTestSupport"),
            ]
        ),
    ]
)
