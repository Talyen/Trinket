import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct ItemAffixMagnitudeRollTests {
    @Test(arguments: [("leeching", "double_axe", 26), ("vampiric", "ruby_ring", 13)])
    func `saved Leech powers describe their rolled damage fraction without changing strength`(
        affixID: String, baseID: String, displayedPercent: Int,
    ) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: affixID))
        let old = ItemAffixPower(
            description: "Leech restores 13% more Health.",
            modifiers: [.leechGainedPercent(0.13), .maximumHealth(7)],
            triggers: CombatTraitTriggers(healing: HealingTriggers(leechThornsWithoutThorns: 2)),
        )
        let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let item = try ItemFixtures.makeBareItem(
            baseID, affixes: [definition.resolved(for: .basic)], affixPowers: decoded,
        )
        let power = try #require(item.resolvedPower(at: 0))
        let multiplier = item.baseType.affixPowerMultiplier
        #expect(power.modifiers == old.scaled(by: multiplier).modifiers)
        #expect(power.triggers == old.scaled(by: multiplier).triggers)
        #expect(power.description == "Leech restores an additional \(displayedPercent)% of damage dealt.")
        #expect(item.displayedAffixes.first?.description == power.description)
        #expect(item.affixPowers == decoded)
    }

    @Test func `boolean only affixes do not roll`() throws {
        let branding = try #require(GameContent.itemAffixDefinition(matching: "branding"))
        try #expect(!branding.basic.hasRollableMagnitudes)
        var rng = SeededRandomNumberGenerator(seed: 3)
        try #expect(branding.basic.rolled(using: &rng) == branding.basic)
        try #expect(!branding.basic.isAtOrAboveRollMax(of: branding.basic))
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

        try #expect(bumped.isPerfectAffix(at: 0))
    }
}
