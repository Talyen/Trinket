// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BattleEngine",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "BattleEngine",
            targets: ["BattleEngine"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
    ],
    targets: [
        .target(
            name: "BattleEngine",
            dependencies: ["TrinketCore", "TrinketContent"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=off"]),
            ]
        ),
        .testTarget(
            name: "BattleEngineTests",
            dependencies: ["BattleEngine", "TrinketCore", "TrinketContent"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=off"]),
            ]
        ),
    ]
)
