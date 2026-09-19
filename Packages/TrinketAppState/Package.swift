// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "TrinketAppState",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "TrinketAppState",
            targets: ["TrinketAppState"],
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../BattleEngine"),
        .package(path: "../TrinketPersistence"),
        .package(path: "../TrinketFeatureSupport"),
        .package(path: "../TrinketBattleFeature"),
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
            ],
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
                .product(name: "TrinketFeatureContracts", package: "TrinketFeatureSupport"),
                "TrinketBattleFeature",
                .product(name: "TrinketContentTestSupport", package: "TrinketContent"),
                .product(name: "TrinketPersistenceTestSupport", package: "TrinketPersistence"),
            ],
        ),
    ],
)
