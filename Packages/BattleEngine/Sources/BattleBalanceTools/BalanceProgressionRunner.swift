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
        let work = config.workIndices(count: totalRuns)
        guard !work.isEmpty else { return ([], [], [], 0) }
        let roster = config.resolvedRoster
        precondition(!roster.heroes.isEmpty && !roster.companions.isEmpty)

        let results = SweepWorkerPool.map(count: work.count, jobs: config.resolvedJobs) { index in
            simulateRun(config: config, policy: policy, roster: roster, runIndex: work.lowerBound + index)
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
        roster: BalanceSweepRoster,
        runIndex: Int,
    ) -> (records: [ProgressionBattleRecord], endState: PlayerProgressionState, didTruncate: Bool) {
        let runSeed = config.seed &+ UInt64(runIndex) &* 1000003
        let hero = roster.heroes[runIndex % roster.heroes.count]
        let companion = roster.companions[(runIndex / roster.heroes.count) % roster.companions.count]
        let controller = InterleavingPlayerController(
            hero: hero, companion: companion,
            campaignTracker: .campaign(worldSeed: runSeed), worldSeed: runSeed,
            equipmentModel: config.resolvedProgressionEquipmentModel,
        )
        var records: [ProgressionBattleRecord] = []
        var stepCounter = 0

        while !controller.isComplete, stepCounter < maxBattlesPerRun {
            guard let step = controller.selectNextStep() else { break }
            stepCounter += 1

            let battleSeed = runSeed &+ UInt64(stepCounter) &* 97
            let matchup = controller.makeMatchup(for: step, seed: battleSeed)

            var battle = BattleSimulator.makeBattle(matchup: matchup, appliesFightPacing: config.appliesFightPacing)
            let result = BattleSimulator.run(
                battle: &battle, policy: policy, maxRounds: config.maxRounds, maxActions: config.maxActions,
            )

            let recordedPlayerLevel = Int(controller.state.averageLevel.rounded())
            let record = ProgressionBattleRecord(
                step: step,
                playerLevel: recordedPlayerLevel,
                enemyLevel: controller.encounterLevel(for: step),
                seed: battleSeed,
                result: result,
            )
            records.append(record)

            controller.recordOutcome(
                step: step, won: result.isVictory,
                defeatProgress: result.timedOut ? nil : battle.defeatProgress,
            )
        }

        return (records, controller.state, !controller.isComplete)
    }
}
