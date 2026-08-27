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
                "TrinketPersistence",
                "TrinketFeatureSupport",
                .product(name: "TrinketFeatureContracts", package: "TrinketFeatureSupport"),
                .product(name: "TrinketFeatureAdapters", package: "TrinketFeatureSupport"),
                "TrinketBattleFeature",
                .product(name: "TrinketTestSupport", package: "TrinketTestSupport"),
                .product(name: "TrinketPersistenceTestSupport", package: "TrinketPersistence"),
            ]
        ),
    ]
)
