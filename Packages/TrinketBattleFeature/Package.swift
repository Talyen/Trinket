// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "TrinketBattleFeature",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "TrinketBattleFeature",
            targets: ["TrinketBattleFeature"],
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../BattleEngine"),
        .package(path: "../TrinketDesignSystem"),
        .package(path: "../TrinketFeatureSupport"),
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
            ],
            resources: [
                .process("Resources/Localizable.xcstrings"),
                .copy("Resources/BossIdles"),
            ],
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
                .product(name: "TrinketContentTestSupport", package: "TrinketContent"),
            ],
        ),
    ],
)
