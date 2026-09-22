import Foundation
import Testing
import TrinketCore
@testable import TrinketContent

struct ItemLootPolicyTests {
    @Test(arguments: [
        (1, [0.98, 0.015, 0.004, 0.001]),
        (40, [0.60, 0.20, 0.12, 0.08]),
        (Int.min, [0.98, 0.015, 0.004, 0.001]),
        (Int.max, [0.60, 0.20, 0.12, 0.08]),
    ])
    func `endpoints match authored weights and clamp`(level: Int, expected: [Double]) {
        let actual = probabilities(level: level)
        for (value, target) in zip(actual, expected) {
            #expect(abs(value - target) < 1e-12)
        }
    }

    @Test func `premium share climbs smoothly to level 40`() {
        var previous = -Double.infinity
        for level in 1 ... 40 {
            let premium = 1 - probabilities(level: level)[0]
            #expect(premium > previous)
            previous = premium
        }
        let ten = 1 - probabilities(level: 10)[0]
        let twenty = 1 - probabilities(level: 20)[0]
        let thirty = 1 - probabilities(level: 30)[0]
        let forty = 1 - probabilities(level: 40)[0]
        #expect(ten < twenty)
        #expect(twenty < thirty)
        #expect(thirty < forty)
        #expect(twenty < forty)
    }

    @Test(arguments: [false, true])
    func `sanctum scales astral weight before normalization`(boss: Bool) {
        let base = probabilities(level: 1, boss: boss)
        let boosted = probabilities(level: 1, boss: boss, bonus: 20)
        #expect(abs(boosted[1] / boosted[0] - base[1] / base[0] * 1.2) < 1e-12)
        #expect(abs(boosted[2] / boosted[0] - base[2] / base[0]) < 1e-12)
        #expect(abs(boosted.reduce(0, +) - 1) < 1e-12)
        #expect(probabilities(level: 1, boss: boss, bonus: -20) == base)
    }

    @Test func `boss triples premium weights and retains basic rewards`() {
        for level in 1 ... 40 {
            let ordinary = probabilities(level: level)
            let boss = probabilities(level: level, boss: true)
            #expect(boss[0] > 0)
            for index in 1 ... 3 {
                #expect(abs(boss[index] / boss[0] - ordinary[index] / ordinary[0] * 3) < 1e-12)
            }
        }
    }

    @Test func `unavailable tiers are removed without donating their weights`() {
        let available: Set<ItemDropTier> = [.basic, .astral]
        let actual = ItemLootPolicy.probabilities(
            level: 40, bossContent: false, astralChanceBonusPercent: 20, availableTiers: available,
        )
        #expect(actual[2] == 0 && actual[3] == 0)
        #expect(abs(actual[1] / actual[0] - 24 / 60) < 1e-12)
    }

    @Test func `opening draws can reach every tier`() {
        // Level-1 weights are all nonzero, so every tier is reachable; roll
        // maps concentrated distributions deterministically for any draw.
        #expect(probabilities(level: 1).allSatisfy { $0 > 0 })
        var rng = SeededRandomNumberGenerator(seed: 42)
        #expect(ItemLootPolicy.roll(probabilities: [1, 0, 0, 0], using: &rng) == .basic)
        #expect(ItemLootPolicy.roll(probabilities: [0, 1, 0, 0], using: &rng) == .astral)
        #expect(ItemLootPolicy.roll(probabilities: [0, 0, 1, 0], using: &rng) == .trinket)
        #expect(ItemLootPolicy.roll(probabilities: [0, 0, 0, 1], using: &rng) == .unique)
    }

    @Test(arguments: [ItemDropTier.astral, .trinket, .unique], [false, true])
    func `favored tier multiplies existing weights and preserves eligibility`(tier: ItemDropTier, boss: Bool) throws {
        let base = probabilities(level: 20, boss: boss, bonus: 20)
        let boosted = ItemLootPolicy.probabilities(
            level: 20, bossContent: boss, astralChanceBonusPercent: 20,
            availableTiers: Set(ItemDropTier.allCases), favoredTier: tier, tierWeightBonusPercent: 25,
        )
        let index = try #require(ItemDropTier.allCases.firstIndex(of: tier))
        for other in 1 ... 3 {
            let multiplier = other == index ? 1.25 : 1
            #expect(abs(boosted[other] / boosted[0] - base[other] / base[0] * multiplier) < 1e-12)
        }
        #expect(abs(boosted.reduce(0, +) - 1) < 1e-12)
        let available = Set(ItemDropTier.allCases).subtracting([tier])
        let exhausted = ItemLootPolicy.probabilities(
            level: 20, bossContent: boss, astralChanceBonusPercent: 20,
            availableTiers: available, favoredTier: tier, tierWeightBonusPercent: 25,
        )
        #expect(exhausted == ItemLootPolicy.probabilities(
            level: 20, bossContent: boss, astralChanceBonusPercent: 20, availableTiers: available,
        ))
        #expect(exhausted[index] == 0)
    }

    private func probabilities(level: Int, boss: Bool = false, bonus: Int = 0) -> [Double] {
        ItemLootPolicy.probabilities(
            level: level, bossContent: boss, astralChanceBonusPercent: bonus,
            availableTiers: Set(ItemDropTier.allCases),
        )
    }
}
