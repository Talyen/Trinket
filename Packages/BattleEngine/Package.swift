// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BattleEngine",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "BattleEngine",
            targets: ["BattleEngine"],
        ),
        .library(
            name: "BattleBalanceTools",
            targets: ["BattleBalanceTools"],
        ),
        .executable(
            name: "BalanceSweepCLI",
            targets: ["BalanceSweepCLI"],
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../TrinketTestSupport"),
    ],
    targets: [
        .target(
            name: "BattleEngine",
            dependencies: ["TrinketCore", "TrinketContent"],
        ),
        .target(
            name: "BattleBalanceTools",
            dependencies: ["BattleEngine", "TrinketCore", "TrinketContent"],
            path: "Sources/BattleBalanceTools",
        ),
        .executableTarget(
            name: "BalanceSweepCLI",
            dependencies: ["BattleBalanceTools", "BattleEngine", "TrinketContent"],
        ),
        .testTarget(
            name: "BattleEngineTests",
            dependencies: [
                "BattleEngine",
                "BattleBalanceTools",
                "TrinketCore",
                "TrinketContent",
                .product(name: "TrinketTestSupport", package: "TrinketTestSupport"),
            ],
        ),
        .testTarget(
            name: "BattleBalanceToolsTests",
            dependencies: [
                "BattleBalanceTools",
                "BattleEngine",
                "TrinketCore",
                "TrinketContent",
            ],
            path: "Tests/BattleBalanceToolsTests",
        ),
    ],
)
