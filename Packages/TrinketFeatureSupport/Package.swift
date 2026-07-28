// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketFeatureSupport",
    platforms: [.iOS(.v26)],
    products: [
        .library(
            name: "TrinketFeatureSupport",
            targets: ["TrinketFeatureSupport"]
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
            name: "TrinketFeatureSupport",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketPersistence",
                "TrinketDesignSystem",
            ]
        ),
        .testTarget(
            name: "TrinketFeatureSupportTests",
            dependencies: [
                "TrinketFeatureSupport",
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
                "TrinketPersistence",
                "TrinketDesignSystem",
            ]
        ),
    ]
)
