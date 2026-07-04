// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "BattleEngine",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BattleEngine",
            targets: ["BattleEngine"]
        ),
        .library(
            name: "BattleBalanceTools",
            targets: ["BattleBalanceTools"]
        ),
        .executable(
            name: "BalanceSweepCLI",
            targets: ["BalanceSweepCLI"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
    ],
    targets: [
        .target(
            name: "BattleEngine",
            dependencies: ["TrinketCore", "TrinketContent"]
        ),
        .target(
            name: "BattleBalanceTools",
            dependencies: ["BattleEngine", "TrinketCore", "TrinketContent"]
        ),
        .executableTarget(
            name: "BalanceSweepCLI",
            dependencies: ["BattleBalanceTools", "TrinketContent"]
        ),
        .testTarget(
            name: "BattleEngineTests",
            dependencies: ["BattleEngine", "BattleBalanceTools", "TrinketCore", "TrinketContent"]
        ),
    ]
)
