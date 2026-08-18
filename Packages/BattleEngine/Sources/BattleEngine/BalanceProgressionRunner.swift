import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public enum BalanceProgressionRunner {
    /// Safety cap per run so a loss-heavy loop cannot run forever.
    public static let maxBattlesPerRun = 1000

    public static func run(
        config: BalanceSweepConfig,
        policy: GreedyHeuristicPolicy = GreedyHeuristicPolicy()
    ) -> (
        records: [ProgressionBattleRecord],
        hotspots: [NodeHotspotSummary],
        playerStates: [PlayerProgressionState],
        truncatedRuns: Int
    ) {
        let totalRuns = max(1, config.battlesPerTier)
        let work = config.sliceWork(Array(0 ..< totalRuns))

        let results = ParallelMap.map(work, jobs: config.resolvedJobs) { runIndex in
            simulateRun(config: config, policy: policy, runIndex: runIndex)
        }

        let allRecords = results.flatMap(\.records)
        let allStates = results.map(\.endState)
        let truncatedRuns = results.filter(\.didTruncate).count
        let hotspots = HotspotAnalyzer.analyze(records: allRecords)

        return (allRecords, hotspots, allStates, truncatedRuns)
    }

    private static func simulateRun(
        config: BalanceSweepConfig,
        policy: GreedyHeuristicPolicy,
        runIndex: Int
    ) -> (records: [ProgressionBattleRecord], endState: PlayerProgressionState, didTruncate: Bool) {
        let runSeed = config.seed &+ UInt64(runIndex) &* 1000003
        let controller = InterleavingPlayerController()
        var records: [ProgressionBattleRecord] = []
        var stepCounter = 0

        while !controller.isComplete, stepCounter < maxBattlesPerRun {
            guard let step = controller.selectNextStep() else { break }
            stepCounter += 1

            let battleSeed = runSeed &+ UInt64(stepCounter) &* 97
            let matchup = controller.makeMatchup(for: step, seed: battleSeed)

            let result = BattleSimulator.run(
                matchup: matchup,
                policy: policy,
                maxRounds: config.maxRounds,
                maxActions: config.maxActions
            )

            let record = ProgressionBattleRecord(
                step: step,
                playerLevel: Int(controller.state.averageLevel.rounded()),
                enemyLevel: step.enemyLevel,
                seed: battleSeed,
                result: result
            )
            records.append(record)

            controller.recordOutcome(step: step, won: result.isVictory)
        }

        return (records, controller.state, !controller.isComplete)
    }
}
