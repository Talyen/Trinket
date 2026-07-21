// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TrinketContent",
    platforms: [
        .iOS(.v26),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "TrinketContent",
            targets: ["TrinketContent"]
        ),
        .executable(
            name: "AbilityInventoryDump",
            targets: ["AbilityInventoryDump"]
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
    ],
    targets: [
        .target(
            name: "TrinketContent",
            dependencies: ["TrinketCore"],
            exclude: [
                "Generated/AbilityInventory.generated.tsv",
                "Generated/ArtSourceHashes.generated.tsv",
            ]
        ),
        .executableTarget(
            name: "AbilityInventoryDump",
            dependencies: ["TrinketContent"]
        ),
        .testTarget(
            name: "TrinketContentTests",
            dependencies: ["TrinketContent"]
        ),
    ]
)
