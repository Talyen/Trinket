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
        .executableTarget(
            name: "BalanceSweepCLI",
            dependencies: ["BattleEngine", "TrinketContent"]
        ),
        .testTarget(
            name: "BattleEngineTests",
            dependencies: ["BattleEngine", "TrinketCore", "TrinketContent"]
        ),
    ]
)
