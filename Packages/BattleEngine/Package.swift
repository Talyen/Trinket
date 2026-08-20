// swift-tools-version: 6.2

import PackageDescription

let balanceToolSources = [
    "BalanceAbilityContrastRunner.swift",
    "BalanceAffixContrastRunner.swift",
    "BalanceContrastFlags.swift",
    "BalanceContrastSupport.swift",
    "BalanceDurationAggregation.swift",
    "BalanceFindingsReporter.swift",
    "BalanceIdentityMargins.swift",
    "BalanceIdentityTables.swift",
    "BalanceMarkdownReporter.swift",
    "BalanceMarkdownTables.swift",
    "BalanceProgressionReportFormatter.swift",
    "BalanceProgressionRunner.swift",
    "BalanceStatsAggregator.swift",
    "BalanceSweepConfig.swift",
    "BalanceSweepReportMerge.swift",
    "BalanceSweepRunner.swift",
    "BalanceSweepWorkPlan.swift",
    "BalanceTalentContrastRunner.swift",
    "BattleSimulator.swift",
    "HotspotAnalyzer.swift",
    "InterleavingPlayerController.swift",
    "ModeProgressionTracker.swift",
    "SimulationMatchupBuilder.swift",
    "SimulationTierProfile.swift",
]

let balanceToolTestSources = [
    "BalanceFindingsReporterTests.swift",
    "BalanceSweepOrchestrationTests.swift",
    "BattleSimulatorSweepReportTests.swift",
    "BattleSimulatorTests.swift",
]

let package = Package(
    name: "BattleEngine",
    platforms: [
        .iOS(.v26),
        .macOS(.v15),
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
        .package(path: "../TrinketTestSupport"),
    ],
    targets: [
        .target(
            name: "BattleEngine",
            dependencies: ["TrinketCore", "TrinketContent"],
            exclude: balanceToolSources
        ),
        .target(
            name: "BattleBalanceTools",
            dependencies: ["BattleEngine", "TrinketCore", "TrinketContent"],
            path: "Sources/BattleEngine",
            sources: balanceToolSources
        ),
        .executableTarget(
            name: "BalanceSweepCLI",
            dependencies: ["BattleBalanceTools", "BattleEngine", "TrinketContent"]
        ),
        .testTarget(
            name: "BattleEngineTests",
            dependencies: [
                "BattleEngine",
                "TrinketCore",
                "TrinketContent",
                .product(name: "TrinketTestSupport", package: "TrinketTestSupport"),
            ],
            exclude: balanceToolTestSources
        ),
        .testTarget(
            name: "BattleBalanceToolsTests",
            dependencies: [
                "BattleBalanceTools",
                "BattleEngine",
                "TrinketCore",
                "TrinketContent",
            ],
            path: "Tests/BattleEngineTests",
            sources: balanceToolTestSources
        ),
    ]
)
