import BattleEngine
import Testing
@testable import BattleBalanceTools

@Suite(.serialized)
@MainActor
struct BalanceSweepSliceTests {
    @Test func `identity slices replay exact records across enemy and tier boundaries`() {
        let config = Self.config(mode: .identity)
        let complete = BalanceSweepRunner.run(config: config)
        let slices = Self.slices(config, count: complete.records.count).map {
            BalanceSweepRunner.run(config: $0)
        }
        #expect(slices.flatMap(\.records) == complete.records)
    }

    @Test func `contrast slices preserve paired outcomes across focus and tier boundaries`() {
        let config = Self.config(mode: .abilityContrast)
        let complete = BalanceSweepRunner.run(config: config)
        let count = BalanceAbilityContrastRunner.workCount(config: config)
        let slices = Self.slices(config, count: count).map {
            BalanceSweepRunner.run(config: $0)
        }
        let merged = BalanceSweepReport.merged(slices, config: config, policyID: config.policyID, elapsedSeconds: 0)
        #expect(merged.abilityContrasts.count == complete.abilityContrasts.count)
        for (actual, expected) in zip(merged.abilityContrasts, complete.abilityContrasts) {
            #expect(actual.entityID == expected.entityID && actual.baselineID == expected.baselineID)
            #expect(actual.ownerID == expected.ownerID && actual.tier == expected.tier)
            #expect(actual.pairs == expected.pairs && actual.decidedPairs == expected.decidedPairs)
            #expect(actual.winsWithEntity == expected.winsWithEntity && actual.winsWithBaseline == expected.winsWithBaseline)
            #expect(actual.entityOnlyWins == expected.entityOnlyWins && actual.baselineOnlyWins == expected.baselineOnlyWins)
            #expect(actual.entityTimeouts == expected.entityTimeouts && actual.baselineTimeouts == expected.baselineTimeouts)
            #expect(abs(actual.meanDeltaPartyHP - expected.meanDeltaPartyHP) < 1e-12)
            #expect(abs(actual.meanDeltaRounds - expected.meanDeltaRounds) < 1e-12)
            #expect(actual.lift == expected.lift && actual.flagReason == expected.flagReason)
        }
    }

    @Test func `work slices clip oversized limits without overflow or allocation`() {
        let config = BalanceSweepConfig(workOffset: 7, workLimit: Int.max)
        #expect(config.workIndices(count: 10) == 7 ..< 10)
        #expect(config.sliceWork(Array(0 ..< 10)) == [7, 8, 9])
        #expect(config.workIndices(count: 0).isEmpty)
        #expect(BalanceSweepConfig(workOffset: Int.max).workIndices(count: 10).isEmpty)
        #expect(BalanceSweepConfig(workLimit: 0).workIndices(count: Int.max).isEmpty)
        #expect(BalanceSweepConfig(workOffset: Int.max - 2, workLimit: 1).workIndices(count: Int.max) == (Int.max - 2) ..< (Int.max - 1))
    }

    private static func config(mode: BalanceSweepMode) -> BalanceSweepConfig {
        BalanceSweepConfig(
            mode: mode, battlesPerTier: 2, seed: 7, tiers: [.early, .middle],
            maxRounds: 10, jobs: 1, heroIDs: ["knight"], companionIDs: ["bear"],
            enemyIDs: ["living_armor", "goblin"], focusIDs: ["bash"],
        )
    }

    private static func slices(_ config: BalanceSweepConfig, count: Int) -> [BalanceSweepConfig] {
        // An odd chunk crosses the even sample groups instead of only testing
        // slices aligned with one enemy, tier, or focus.
        BalanceSweepWorkPlan.chunkRanges(workCount: count, chunkSize: 3).map { range in
            var slice = config
            slice.workOffset = range.offset
            slice.workLimit = range.limit
            return slice
        }
    }
}
