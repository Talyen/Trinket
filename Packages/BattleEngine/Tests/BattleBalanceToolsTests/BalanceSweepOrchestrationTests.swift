import BattleEngine
import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleBalanceTools

struct BalanceSweepOrchestrationTests {
    @Test func `work plan chunks cover exact count`() {
        let ranges = BalanceSweepWorkPlan.chunkRanges(workCount: 34, chunkSize: 16)
        #expect(ranges.map(\.offset) == [0, 16, 32])
        #expect(ranges.map(\.limit) == [16, 16, 2])
        let jobs = BalanceSweepWorkPlan.workerJobs(
            config: BalanceSweepConfig(
                mode: .identity,
                battlesPerTier: 20,
                tiers: SimulationPowerTier.allCases,
                enemyIDs: ["living_armor"],
            ),
        )
        #expect(jobs.count == 4)
        #expect(jobs.allSatisfy { $0.mode == .identity })
        #expect(jobs.map(\.limit).reduce(0, +) == 60)
    }

    @Test func `contrast slice merge recomputes lift and flags`() {
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
            flagged: false,
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
            flagged: false,
        )
        let merged = BalanceSweepReport.merged(
            [
                BalanceSweepReport(config: config, policyID: "greedy-v1", abilityContrasts: [first], elapsedSeconds: 0),
                BalanceSweepReport(config: config, policyID: "greedy-v1", abilityContrasts: [second], elapsedSeconds: 0),
            ],
            config: config,
            policyID: "greedy-v1",
            elapsedSeconds: 0,
        )
        let row = merged.abilityContrasts[0]
        #expect(merged.abilityContrasts.count == 1)
        #expect(row.pairs == 8)
        #expect(row.winsWithEntity == 8)
        #expect(row.lift == 1)
        #expect(row.flagged)
        #expect(row.flagReason == "HIGH")
    }

    @Test func `contrast comfort deltas ignore timeout pairs`() {
        var acc = BalanceContrastFlags.ContrastAcc(
            entityID: "a",
            baselineID: "b",
            ownerID: "hero",
            tier: .early,
            baselineKind: .sibling,
            nonCombat: false,
        )
        let timeout = BattleSimResult(
            outcome: .defeat,
            rounds: 100,
            actions: 500,
            timedOut: true,
            partyHPRemainingFraction: 0.9,
            enemyHPRemainingFraction: 0.1,
        )
        let decided = BattleSimResult(
            outcome: .victory,
            rounds: 6,
            actions: 10,
            timedOut: false,
            partyHPRemainingFraction: 0.5,
            enemyHPRemainingFraction: 0,
        )
        acc.accumulate(entity: timeout, baseline: decided)
        for _ in 0 ..< 8 {
            acc.accumulate(entity: decided, baseline: decided)
        }
        let summary = BalanceContrastFlags.makeSummary(
            acc,
            config: BalanceSweepConfig(mode: .abilityContrast, battlesPerTier: 8, jobs: 1),
        )
        #expect(summary.pairs == 9)
        #expect(summary.decidedPairs == 8)
        #expect(summary.meanDeltaPartyHP == 0)
        #expect(summary.flagReason != "SAFER")
        #expect(summary.flagReason != "GLASS")
    }

    @Test func `unknown roster filters resolve empty`() {
        let roster = BalanceSweepConfig(
            mode: .identity,
            battlesPerTier: 1,
            heroIDs: ["missing-hero"],
        ).resolvedRoster
        #expect(roster.heroes.isEmpty)
    }

    @Test func `sweep report JSON round trips`() throws {
        let config = BalanceSweepConfig(
            mode: .identity,
            battlesPerTier: 1,
            seed: 3,
            tiers: [.early],
            jobs: 1,
            enemyIDs: ["living_armor"],
        )
        let report = BalanceSweepReport(
            config: config,
            policyID: "greedy-v1",
            records: [
                BalanceBattleRecord(
                    tier: .early,
                    heroID: "knight",
                    companionID: "bear",
                    enemyID: "living_armor",
                    isBoss: false,
                    heroAbilityIDs: ["slash"],
                    companionAbilityIDs: ["bash"],
                    enemyAbilityIDs: ["strike"],
                    enemyTraitID: "",
                    affixIDs: [],
                    heroTalentIDs: [],
                    companionTalentIDs: [],
                    seed: 3,
                    policyID: "greedy-v1",
                    result: BattleSimResult(
                        outcome: .victory,
                        rounds: 2,
                        actions: 4,
                        timedOut: false,
                        partyHPRemainingFraction: 0.8,
                        enemyHPRemainingFraction: 0,
                    ),
                ),
            ],
            elapsedSeconds: 0.01,
        )
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(BalanceSweepReport.self, from: data)
        #expect(decoded.records.map(\.seed) == report.records.map(\.seed))
        #expect(decoded.records.map(\.result) == report.records.map(\.result))
    }

    @Test func `ability contrast work count is foci times samples times tiers`() {
        let config = BalanceSweepConfig(
            mode: .abilityContrast,
            battlesPerTier: 3,
            tiers: [.early],
            heroIDs: ["knight"],
            companionIDs: ["bear"],
        )
        let foci = BalanceAbilityContrastRunner.foci(
            heroes: config.resolvedRoster.heroes,
            companions: config.resolvedRoster.companions,
            focusIDs: [],
        )
        #expect(BalanceAbilityContrastRunner.workCount(config: config) == foci.count * 3)
        let expectedPairs = (config.resolvedRoster.heroes + config.resolvedRoster.companions).reduce(0) { total, owner in
            total + AbilityTier.allCases.reduce(0) { tierTotal, tier in
                let n = owner.abilityChoices.abilities(for: tier).count
                return tierTotal + (n * (n - 1) / 2)
            }
        }
        #expect(foci.count == expectedPairs)
        #expect(!foci.isEmpty)
    }

    @Test func `affix contrast work plan includes starter gear`() {
        let mixed = BalanceSweepWorkPlan.workerJobs(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 10,
                tiers: SimulationPowerTier.allCases,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                focusIDs: ["keen"],
            ),
        )
        #expect(mixed.map(\.limit).reduce(0, +) == BalanceAffixContrastRunner.workCount(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 10,
                tiers: SimulationPowerTier.allCases,
                heroIDs: ["knight"],
                companionIDs: ["bear"],
                focusIDs: ["keen"],
            ),
        ))

        let earlyOnly = BalanceSweepWorkPlan.workerJobs(
            config: BalanceSweepConfig(
                mode: .affixContrast,
                battlesPerTier: 10,
                tiers: [.early],
            ),
        )
        #expect(!earlyOnly.isEmpty)
    }

    @Test func `identity win rate excludes timeouts`() {
        let timeout = BattleSimResult(
            outcome: .defeat,
            rounds: 100,
            actions: 500,
            timedOut: true,
            partyHPRemainingFraction: 0.5,
            enemyHPRemainingFraction: 0.5,
        )
        let win = BattleSimResult(
            outcome: .victory,
            rounds: 6,
            actions: 10,
            timedOut: false,
            partyHPRemainingFraction: 0.8,
            enemyHPRemainingFraction: 0,
        )
        func record(_ result: BattleSimResult, seed: UInt64) -> BalanceBattleRecord {
            BalanceBattleRecord(
                tier: .early,
                heroID: "knight",
                companionID: "bear",
                enemyID: "living_armor",
                isBoss: false,
                heroAbilityIDs: ["bash"],
                companionAbilityIDs: ["swipe"],
                enemyAbilityIDs: ["slash"],
                enemyTraitID: "living_armor_trait",
                affixIDs: [],
                heroAffixIDs: [],
                companionAffixIDs: [],
                heroTalentIDs: [],
                companionTalentIDs: [],
                seed: seed,
                policyID: "greedy-v1",
                result: result,
            )
        }
        let report = BalanceSweepReport(
            config: BalanceSweepConfig(mode: .identity, battlesPerTier: 2, tiers: [.early], jobs: 1),
            policyID: "greedy-v1",
            records: [record(timeout, seed: 1), record(win, seed: 2)],
            elapsedSeconds: 0,
        )
        let stats = BalanceStatsAggregator.summarize(report: report)[0]
        #expect(stats.timeouts == 1)
        #expect(stats.decidedBattles == 1)
        #expect(stats.wins == 1)
        #expect(stats.heroes.first?.winRate == 1)
    }

    @Test func `identity sampling balances partners and preserves filtered enemy replay`() throws {
        let heroes = Array(GameContent.heroes.prefix(3))
        let companions = Array(GameContent.companions.prefix(4))
        let enemies = Array(GameContent.enemies.prefix(2))
        let config = BalanceSweepConfig(
            battlesPerTier: 12, tiers: [.early], maxRounds: 1, jobs: 1,
        )
        let report = BalanceSweepRunner.run(
            config: config, heroes: heroes, companions: companions, enemies: enemies,
        )
        let enemy = try #require(enemies.last)
        let records = report.records.filter { $0.enemyID == enemy.id }
        let pairs = Set(records.map { "\($0.heroID)|\($0.companionID)" })
        #expect(pairs.count == heroes.count * companions.count)
        for companion in companions {
            #expect(records.count { $0.companionID == companion.id } == 3)
        }
        let filtered = BalanceSweepRunner.run(
            config: config, heroes: heroes, companions: companions, enemies: [enemy],
        )
        #expect(filtered.records == records)
    }

    @Test func `contrast stalls survive aggregation and merge without becoming losses`() {
        let config = BalanceSweepConfig(mode: .abilityContrast, jobs: 1)
        var acc = BalanceContrastFlags.ContrastAcc(
            entityID: "a", baselineID: "b", ownerID: "hero", tier: .early,
            baselineKind: .sibling, nonCombat: false,
        )
        let timeout = BattleSimResult(
            outcome: .defeat, rounds: 1, actions: 500, timedOut: true,
            partyHPRemainingFraction: 1, enemyHPRemainingFraction: 1,
        )
        let win = BattleSimResult(
            outcome: .victory, rounds: 6, actions: 10, timedOut: false,
            partyHPRemainingFraction: 0.5, enemyHPRemainingFraction: 0,
        )
        for _ in 0 ..< 4 {
            acc.accumulate(entity: timeout, baseline: win)
        }
        let partial = BalanceContrastFlags.makeSummary(acc, config: config)
        #expect(!partial.flagged)
        let merged = BalanceContrastSupport.mergeSummaries([partial, partial], config: config)
        #expect(merged.first?.flagReason == "ENTITY STALL")
        #expect(merged.first?.decidedPairs == 0)
        #expect(merged.first?.winsWithBaseline == 0)
        #expect(merged.first?.entityTimeouts == 8)
    }

    @Test func `wilson interval contains point estimate`() {
        let ci = BalanceStatsAggregator.wilson(wins: 80, battles: 100)
        #expect(ci.low <= 0.80)
        #expect(ci.high >= 0.80)
        #expect(ci.low < ci.high)
    }
}
