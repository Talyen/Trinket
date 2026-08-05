// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketFeatureSupport",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "TrinketFeatureContracts",
            targets: ["TrinketFeatureContracts"]
        ),
        .library(
            name: "TrinketBattleContracts",
            targets: ["TrinketBattleContracts"]
        ),
        .library(
            name: "TrinketFeatureSupport",
            targets: ["TrinketFeatureSupport"]
        ),
        .library(
            name: "TrinketFeatureAdapters",
            targets: ["TrinketFeatureAdapters"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../BattleEngine"),
        .package(path: "../TrinketPersistence"),
        .package(path: "../TrinketDesignSystem"),
    ],
    targets: [
        .target(
            name: "TrinketFeatureContracts",
            dependencies: []
        ),
        .target(
            name: "TrinketBattleContracts",
            dependencies: [
                "TrinketContent",
                "TrinketCore",
                "TrinketFeatureContracts",
            ],
            path: "Sources/TrinketBattleContracts"
        ),
        .target(
            name: "TrinketFeatureSupport",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                "TrinketDesignSystem",
                "TrinketPersistence",
            ]
        ),
        .target(
            name: "TrinketFeatureAdapters",
            dependencies: [
                "TrinketFeatureSupport",
                "TrinketFeatureContracts",
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketPersistence",
                "TrinketDesignSystem",
            ],
            path: "Sources/TrinketFeatureAdapters"
        ),
        .testTarget(
            name: "TrinketFeatureSupportTests",
            dependencies: [
                "TrinketFeatureSupport",
                "TrinketCore",
                "TrinketContent",
                "TrinketPersistence",
            ]
        ),
    ]
)
