import Testing
import TrinketContent
import TrinketCore

struct ItemAffixMagnitudeRollTests {
    @Test func integerRangesMatchTheCatalogFormula() {
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 1) == 1 ... 2)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 2) == 1 ... 3)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 3) == 2 ... 4)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 4) == 3 ... 5)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 6) == 5 ... 7)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 8) == 6 ... 10)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 12) == 9 ... 15)
        #expect(ItemAffixMagnitudeRoll.integerRange(around: 16) == 12 ... 20)
    }

    @Test func percentChoicesMatchTheCatalogFormula() {
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.05) == [0.04, 0.05, 0.06])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.10) == [0.08, 0.09, 0.10, 0.11, 0.12])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.20) == [0.15, 0.20, 0.25])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.25) == [0.20, 0.25, 0.30])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 0.50) == [0.40, 0.45, 0.50, 0.55, 0.60])
        #expect(ItemAffixMagnitudeRoll.percentValues(around: 1.00) == [
            0.75, 0.80, 0.85, 0.90, 0.95, 1.00, 1.05, 1.10, 1.15, 1.20, 1.25,
        ])
    }

    @Test func rolledIntegerModifiersStayInRange() throws {
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

    @Test func executionersKeepsHealthThresholdWhileRollingBonus() throws {
        let executioners = try #require(GameContent.itemAffixDefinition(matching: "executioners"))
        let catalog = executioners.basic
        for seed in UInt64(1) ... 40 {
            var rng = SeededRandomNumberGenerator(seed: seed)
            let rolled = catalog.rolled(using: &rng)
            try #expect(rolled.triggers.damageBelowHealthPercentThreshold == 0.30)
            try #expect((2 ... 4).contains(rolled.triggers.damageBelowHealthPercentBonus))
        }
    }

    @Test func booleanOnlyAffixesDoNotRoll() throws {
        let branding = try #require(GameContent.itemAffixDefinition(matching: "branding"))
        try #expect(!branding.basic.hasRollableMagnitudes)
        var rng = SeededRandomNumberGenerator(seed: 3)
        try #expect(branding.basic.rolled(using: &rng) == branding.basic)
        try #expect(!branding.basic.isAtOrAboveRollMax(of: branding.basic))
    }

    @Test func catalogCenterIsNotAPerfectRoll() throws {
        let keen = try #require(GameContent.itemAffixDefinition(matching: "keen"))
        let longsword = try #require(GameContent.itemBaseTypes.first { $0.id == "longsword" })
        let affix = keen.resolved(for: .basic)
        let centerItem = InventoryItem(
            id: "center",
            baseType: longsword,
            rarity: .basic,
            displayName: longsword.name,
            affixes: [affix],
            affixPowers: [keen.basic]
        )
        let missingRollItem = InventoryItem(
            id: "legacy",
            baseType: longsword,
            rarity: .basic,
            displayName: longsword.name,
            affixes: [affix]
        )
        let perfectItem = InventoryItem(
            id: "perfect",
            baseType: longsword,
            rarity: .basic,
            displayName: longsword.name,
            affixes: [affix],
            affixPowers: [
                ItemAffixPower(
                    description: "Increase Physical damage by 2.",
                    modifiers: [.damageDealt(.physical, 2)]
                ),
            ]
        )

        try #expect(!centerItem.isPerfectAffix(at: 0))
        try #expect(!missingRollItem.isPerfectAffix(at: 0))
        try #expect(perfectItem.isPerfectAffix(at: 0))
        try #expect(!perfectItem.isPerfectAffix(at: 1))
    }

    @Test func corruptionBumpToRangeMaxBecomesPerfect() throws {
        let defenders = try #require(GameContent.itemAffixDefinition(matching: "defenders"))
        let kite = try #require(GameContent.itemBaseTypes.first { $0.id == "kite_shield" })
        let affix = defenders.resolved(for: .basic)
        let bumped = InventoryItem(
            id: "bumped",
            baseType: kite,
            rarity: .basic,
            displayName: kite.name,
            affixes: [affix],
            affixPowers: [
                ItemAffixPower(
                    description: "Gain 3 additional Block.",
                    modifiers: [.blockGained(3)]
                ),
            ]
        )

        try #expect(ItemAffixMagnitudeRoll.integerRange(around: 2) == 1 ... 3)
        try #expect(bumped.isPerfectAffix(at: 0))
    }
}
