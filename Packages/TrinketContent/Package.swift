// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "TrinketContent",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
    ],
    products: [
        .executable(name: "LootBalanceReport", targets: ["LootBalanceReport"]),
        .library(
            name: "TrinketContent",
            targets: ["TrinketContent"],
        ),
        .library(
            name: "TrinketContentTestSupport",
            targets: ["TrinketContentTestSupport"],
        ),
        .executable(
            name: "AbilityInventoryDump",
            targets: ["AbilityInventoryDump"],
        ),
    ],
    dependencies: [
        .package(path: "../TrinketCore"),
    ],
    targets: [
        .executableTarget(name: "LootBalanceReport", dependencies: ["TrinketContent"]),
        .target(
            name: "TrinketContent",
            dependencies: ["TrinketCore"],
            // Generated TSVs are codegen inputs/outputs, not bundled resources.
            // Any new generated TSV must be added here AND to
            // Scripts/config/generated-paths.tsv (committed-output gate).
            exclude: [
                "Generated/AbilityInventory.generated.tsv",
                "Generated/AppIconSourceHashes.generated.tsv",
                "Generated/ArtSourceHashes.generated.tsv",
                "Generated/MusicSourceHashes.generated.tsv",
                "Generated/SFXSourceHashes.generated.tsv",
                "Generated/UltimateCinematicSourceHashes.generated.tsv",
            ],
        ),
        .target(
            name: "TrinketContentTestSupport",
            dependencies: ["TrinketContent", "TrinketCore"],
        ),
        .executableTarget(
            name: "AbilityInventoryDump",
            dependencies: ["TrinketContent"],
        ),
        .testTarget(
            name: "TrinketContentTests",
            dependencies: ["TrinketContent", "TrinketCore", "TrinketContentTestSupport"],
        ),
    ],
)
