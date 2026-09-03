import Testing
import TrinketContent
import TrinketCore

struct ItemAffixMagnitudeRollTests {
    @Test func `integer ranges match the catalog formula`() {
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 1) == 1 ... 2)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 2) == 1 ... 3)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 3) == 2 ... 4)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 4) == 3 ... 5)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 6) == 5 ... 7)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 8) == 6 ... 10)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 12) == 9 ... 15)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 16) == 12 ... 20)
    }

    @Test func `percent choices match the catalog formula`() {
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.05) == [0.04, 0.05, 0.06])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.10) == [0.08, 0.09, 0.10, 0.11, 0.12])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.20) == [0.15, 0.20, 0.25])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.25) == [0.20, 0.25, 0.30])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.50) == [0.40, 0.45, 0.50, 0.55, 0.60])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 1.00) == [
            0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.15, 1.20, 1.25,
        ])
    }

    @Test func `rolled integer modifiers stay in range`() throws {
        let keen = try #require(GameContent.itemAffixDefinition(matching: "keen"))
        let catalog = keen.basic
        var seen = Set<Int>()
        for seed in UInt64(1) ... 80 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let rolled = catalog.rolled(using: &rng)
            let value = try #require(rolled.modifiers.first.map { Int($0.numericValue.rounded()) })
            try #expect((1 ... 2).contains(value))
            seen.insert(value)
        }
        try #expect(seen == [1, 2])
    }

    @Test func `executioners keeps health threshold while rolling bonus`() throws {
        let executioners = try #require(GameContent.itemAffixDefinition(matching: "executioners"))
        let catalog = executioners.basic
        for seed in UInt64(1) ... 40 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let rolled = catalog.rolled(using: &rng)
            try #expect(rolled.triggers.damageBelowHealthPercentThreshold == 0.30)
            try #expect((2 ... 4).contains(rolled.triggers.damageBelowHealthPercentBonus))
        }
    }

    @Test func `boolean only affixes do not roll`() throws {
        let branding = try #require(GameContent.itemAffixDefinition(matching: "branding"))
        try #expect(!branding.basic.hasRollableMagnitudes)
        var rng = SeededRandomNumberGenerator(seed: 3)
        try #expect(branding.basic.rolled(using: &rng) == branding.basic)
        try #expect(!branding.basic.isAtOrAboveRollMax(of: branding.basic))
    }

    @Test func `catalog center is not A perfect roll`() throws {
        let keen = try #require(GameContent.itemAffixDefinition(matching: "keen"))
        let affix = keen.resolved(for: .basic)
        let centerItem = try ItemFixtures.makeBareItem(
            "longsword",
            id: "center",
            affixes: [affix],
            affixPowers: [keen.basic],
        )
        let missingRollItem = try ItemFixtures.makeBareItem("longsword", id: "legacy", affixes: [affix])
        let perfectItem = try ItemFixtures.makeBareItem(
            "longsword",
            id: "perfect",
            affixes: [affix],
            affixPowers: [
                ItemAffixPower(
                    description: "Increase Physical damage by 2.",
                    modifiers: [.damageDealt(.physical, 2)],
                ),
            ],
        )

        try #expect(!centerItem.isPerfectAffix(at: 0))
        try #expect(!missingRollItem.isPerfectAffix(at: 0))
        try #expect(perfectItem.isPerfectAffix(at: 0))
        try #expect(!perfectItem.isPerfectAffix(at: 1))
    }

    @Test func `corruption bump to range max becomes perfect`() throws {
        let defenders = try #require(GameContent.itemAffixDefinition(matching: "defenders"))
        let affix = defenders.resolved(for: .basic)
        let bumped = try ItemFixtures.makeBareItem(
            "kite_shield",
            id: "bumped",
            affixes: [affix],
            affixPowers: [
                ItemAffixPower(
                    description: "Gain 3 additional Block.",
                    modifiers: [.blockGained(3)],
                ),
            ],
        )

        try #expect(ItemAffixMagnitudeRoll.integerRange(around: 2) == 1 ... 3)
        try #expect(bumped.isPerfectAffix(at: 0))
    }
}
