import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public enum BalanceProgressionRunner {
    public static let maxBattlesPerRun = 1000

    public static func run(
        config: BalanceSweepConfig,
        policy: PlayPolicy,
    ) -> (
        records: [ProgressionBattleRecord],
        hotspots: [NodeHotspotSummary],
        playerStates: [PlayerProgressionState],
        truncatedRuns: Int,
    ) {
        let totalRuns = max(1, config.battlesPerTier)
        let work = config.sliceWork(Array(0 ..< totalRuns))

        let results = work.map { runIndex in
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
        policy: PlayPolicy,
        runIndex: Int,
    ) -> (records: [ProgressionBattleRecord], endState: PlayerProgressionState, didTruncate: Bool) {
        let runSeed = config.seed &+ UInt64(runIndex) &* 1000003
        let roster = config.resolvedRoster
        let hero = roster.heroes[runIndex % roster.heroes.count]
        let companion = roster.companions[(runIndex / max(roster.heroes.count, 1)) % roster.companions.count]
        let controller = InterleavingPlayerController(hero: hero, companion: companion)
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
                maxActions: config.maxActions,
                appliesFightPacing: config.appliesFightPacing,
            )

            let recordedPlayerLevel = Int(
                ((
                    Double(controller.simulatedHeroLevel(for: step))
                        + Double(controller.simulatedCompanionLevel(for: step))
                ) / 2.0).rounded(),
            )
            let record = ProgressionBattleRecord(
                step: step,
                playerLevel: recordedPlayerLevel,
                enemyLevel: step.enemyLevel,
                seed: battleSeed,
                result: result,
            )
            records.append(record)

            controller.recordOutcome(step: step, won: result.isVictory)
        }

        return (records, controller.state, !controller.isComplete)
    }
}
