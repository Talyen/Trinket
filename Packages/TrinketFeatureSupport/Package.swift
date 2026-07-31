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
            name: "TrinketFeatureSupport",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                "TrinketDesignSystem",
            ]
        ),
        .target(
            name: "TrinketFeatureAdapters",
            dependencies: [
                "TrinketFeatureSupport",
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
                "TrinketFeatureAdapters",
                "TrinketCore",
                "TrinketContent",
                "TrinketPersistence",
            ]
        ),
    ]
)
