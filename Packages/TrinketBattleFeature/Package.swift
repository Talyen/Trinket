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
                "TrinketDesignSystem",
                "TrinketFeatureSupport",
                .product(name: "TrinketFeatureContracts", package: "TrinketFeatureSupport"),
            ]
        ),
        .testTarget(
            name: "TrinketBattleFeatureTests",
            dependencies: [
                "TrinketBattleFeature",
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketDesignSystem",
                "TrinketFeatureSupport",
                .product(name: "TrinketFeatureContracts", package: "TrinketFeatureSupport"),
                .product(name: "TrinketTestSupport", package: "TrinketTestSupport"),
            ]
        ),
    ]
)
