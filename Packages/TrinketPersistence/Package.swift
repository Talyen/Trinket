// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TrinketPersistence",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "TrinketPersistence",
            targets: ["TrinketPersistence"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
        .package(path: "../TrinketContent"),
        .package(path: "../BattleEngine"),
    ],
    targets: [
        .target(
            name: "TrinketPersistence",
            dependencies: ["TrinketCore", "TrinketContent", "BattleEngine"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=off"]),
            ]
        ),
        .testTarget(
            name: "TrinketPersistenceTests",
            dependencies: ["TrinketPersistence", "TrinketCore", "TrinketContent", "BattleEngine"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=off"]),
            ]
        ),
    ]
)
