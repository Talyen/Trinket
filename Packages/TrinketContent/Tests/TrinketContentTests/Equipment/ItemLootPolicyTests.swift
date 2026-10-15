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
        #expect(actual.count == expected.count)
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

    @Test func `weighted draws respect cumulative boundaries and skip unavailable tiers`() throws {
        let initial = SeededRandomNumberGenerator(seed: 42)
        var probe = initial
        let draw = Double.random(in: 0 ..< 1, using: &probe)
        try #require(draw > 0 && draw < 1)
        // Position nontrivial distributions around the exact seeded draw. This
        // catches broken accumulation and inclusive boundaries without sampling
        // generated items or depending on the RNG's bit-to-Double conversion.
        let span = min(draw, 1 - draw) / 4
        let cases: [([Double], ItemDropTier)] = [
            ([draw.nextUp, 0, 0, 1 - draw.nextUp], .basic),
            ([draw / 2, draw / 2 + span, 0, 1 - draw - span], .astral),
            ([draw / 2, draw / 2, span, 1 - draw - span], .trinket),
            ([draw, 0, 0, 1 - draw], .unique),
            ([draw.nextDown, 0, 0, 1 - draw.nextDown], .unique),
        ]
        for (weights, expected) in cases {
            var rng = initial
            #expect(ItemLootPolicy.roll(probabilities: weights, using: &rng) == expected)
        }
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
        let values = ItemLootPolicy.probabilities(
            level: level, bossContent: boss, astralChanceBonusPercent: bonus,
            availableTiers: Set(ItemDropTier.allCases),
        )
        #expect(values.count == ItemDropTier.allCases.count)
        #expect(values.allSatisfy { $0.isFinite && $0 >= 0 })
        #expect(abs(values.reduce(0, +) - 1) < 1e-12)
        return values
    }
}
