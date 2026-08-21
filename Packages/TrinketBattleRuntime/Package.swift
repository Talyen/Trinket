// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketBattleRuntime",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(
            name: "TrinketBattleRuntime",
            targets: ["TrinketBattleRuntime"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../BattleEngine"),
    ],
    targets: [
        .target(
            name: "TrinketBattleRuntime",
            dependencies: [
                "TrinketCore",
                "TrinketContent",
                "BattleEngine",
            ]
        ),
    ]
)
