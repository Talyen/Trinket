import BattleEngine
import Foundation
import Testing
@testable import BattleBalanceTools

struct BalanceSweepOrchestrationTests {
    @Test func workPlanChunksCoverExactCount() {
        let ranges = BalanceSweepWorkPlan.chunkRanges(workCount: 34, chunkSize: 16)
        #expect(ranges.map(\.offset) == [0, 16, 32])
        #expect(ranges.map(\.limit) == [16, 16, 2])
        let jobs = BalanceSweepWorkPlan.workerJobs(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 20,
                tiers: SimulationPowerTier.allCases,
                enemyIDs: ["living_armor"]
            )
        )
        #expect(jobs.count == 4)
        #expect(jobs.allSatisfy { $0.mode == .identity })
        #expect(jobs.map(\.limit).reduce(0, +) == 60)
    }

    @Test func identityWorkSlicesConcatenateToFullSweep() {
        let config = BalanceSweepConfig(
            mode: .identity,
            battlesPerTier: 8,
            seed: 11,
            tiers: [.early],
            jobs: 1,
            enemyIDs: ["living_armor"]
        )
        let full = BalanceSweepRunner.run(config: config)
        let first = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 8,
                seed: 11,
                tiers: [.early],
                jobs: 1,
                workOffset: 0,
                workLimit: 4,
                enemyIDs: ["living_armor"]
            )
        )
        let second = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 8,
                seed: 11,
                tiers: [.early],
                jobs: 1,
                workOffset: 4,
                workLimit: 4,
                enemyIDs: ["living_armor"]
            )
        )
        let merged = BalanceSweepReport.merged(
            [first, second],
            config: config,
            policyID: full.policyID,
            elapsedSeconds: 0
        )
        #expect(first.records.count == 4)
        #expect(second.records.count == 4)
        #expect(merged.records.map(\.result) == full.records.map(\.result))
        #expect(merged.records.map(\.seed) == full.records.map(\.seed))
    }

    @Test func contrastSliceMergeRecomputesLiftAndFlags() {
        let config = BalanceSweepConfig(mode: .abilityContrast, battlesPerTier: 8, seed: 1, jobs: 1)
        let first = PairedContrastSummary(
            entityID: "a",
            baselineID: "b",
            ownerID: "hero",
            tier: .early,
            pairs: 4,
            decidedPairs: 4,
            winsWithEntity: 4,
            winsWithBaseline: 0,
            entityOnlyWins: 4,
            lift: 1,
            flagged: false
        )
        let second = PairedContrastSummary(
            entityID: "a",
            baselineID: "b",
            ownerID: "hero",
            tier: .early,
            pairs: 4,
            decidedPairs: 4,
            winsWithEntity: 4,
            winsWithBaseline: 0,
            entityOnlyWins: 4,
            lift: 1,
            flagged: false
        )
        let merged = BalanceSweepReport.merged(
            [
                BalanceSweepReport(config: config, policyID: "greedy-v1", abilityContrasts: [first], elapsedSeconds: 0),
                BalanceSweepReport(config: config, policyID: "greedy-v1", abilityContrasts: [second], elapsedSeconds: 0),
            ],
            config: config,
            policyID: "greedy-v1",
            elapsedSeconds: 0
        )
        let row = merged.abilityContrasts[0]
        #expect(merged.abilityContrasts.count == 1)
        #expect(row.pairs == 8)
        #expect(row.winsWithEntity == 8)
        #expect(row.lift == 1)
        #expect(row.flagged)
        #expect(row.flagReason == "HIGH")
    }

    @Test func contrastComfortDeltasIgnoreTimeoutPairs() {
        var acc = BalanceContrastFlags.ContrastAcc(
            entityID: "a",
            baselineID: "b",
            ownerID: "hero",
            tier: .early,
            baselineKind: .sibling,
            nonCombat: false
        )
        let timeout = BattleSimResult(
            outcome: .defeat,
            rounds: 100,
            actions: 500,
            timedOut: true,
            partyHPRemainingFraction: 0.9,
            enemyHPRemainingFraction: 0.1
        )
        let decided = BattleSimResult(
            outcome: .victory,
            rounds: 6,
            actions: 10,
            timedOut: false,
            partyHPRemainingFraction: 0.5,
            enemyHPRemainingFraction: 0
        )
        acc.accumulate(entity: timeout, baseline: decided)
        for _ in 0 ..< 8 {
            acc.accumulate(entity: decided, baseline: decided)
        }
        let summary = BalanceContrastFlags.makeSummary(
            acc,
            config: BalanceSweepConfig(mode: .abilityContrast, battlesPerTier: 8, jobs: 1)
        )
        #expect(summary.pairs == 9)
        #expect(summary.decidedPairs == 8)
        #expect(summary.meanDeltaPartyHP == 0)
        #expect(summary.flagReason != "SAFER")
        #expect(summary.flagReason != "GLASS")
    }

    @Test func unknownRosterFiltersResolveEmpty() {
        let roster = BalanceSweepConfig(
            mode: .identity,
            battlesPerTier: 1,
            heroIDs: ["missing-hero"]
        ).resolvedRoster
        #expect(roster.heroes.isEmpty)
    }

    @Test func sweepReportJSONRoundTrips() throws {
        let report = BalanceSweepRunner.run(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 1,
                seed: 3,
                tiers: [.early],
                jobs: 1,
                enemyIDs: ["living_armor"]
            )
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BalanceSweepReport.self, from: data)
        #expect(decoded.records.map(\.seed) == report.records.map(\.seed))
        #expect(decoded.records.map(\.result) == report.records.map(\.result))
    }

    @Test func abilityContrastWorkCountIsFociTimesSamplesTimesTiers() {
        let config = BalanceSweepConfig(
            mode: .abilityContrast,
            battlesPerTier: 3,
            tiers: [.early],
            heroIDs: ["knight"],
            companionIDs: ["bear"]
        )
        let foci = BalanceAbilityContrastRunner.foci(
            heroes: config.resolvedRoster.heroes,
            companions: config.resolvedRoster.companions,
            focusIDs: []
        )
        #expect(BalanceAbilityContrastRunner.workCount(config: config) == foci.count * 3)
        #expect(foci.count == 6)
    }

    @Test func affixContrastWorkPlanCountsOnlyGearTiers() {
        let mixed = BalanceSweepWorkPlan.workerJobs(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 10,
                tiers: SimulationPowerTier.allCases,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                focusIDs: ["keen"]
            )
        )
        #expect(mixed.map(\.limit).reduce(0, +) == BalanceAffixContrastRunner.workCount(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 10,
                tiers: SimulationPowerTier.allCases,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                focusIDs: ["keen"]
            )
        ))

        let earlyOnly = BalanceSweepWorkPlan.workerJobs(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 10,
                tiers: [.early]
            )
        )
        #expect(earlyOnly.isEmpty)
    }
}
