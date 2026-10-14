import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore

struct ItemAffixMagnitudeRollTests {
    @Test(arguments: [1e8, 1e18])
    func `oversized percentage powers preserve strength when rolled`(magnitude: Double) {
        let power = ItemAffixPower(description: "Saved power", modifiers: [.leechGainedPercent(magnitude)])
        var rng = SeededRandomNumberGenerator(seed: 3)
        #expect(power.rolled(using: &rng).modifiers == power.modifiers)
        #expect(power.rolledMax().modifiers == power.modifiers)
        #expect(ItemAffixMagnitudeRoll.percentValues(around: magnitude) == [magnitude])
    }

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
        #expect(power.description == "Leech restores an additional \(displayedPercent)% of damage dealt")
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

    @Test func `oversized saved integer powers remain inspectable and can be weakened`() throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "keen"))
        let stored = ItemAffixPower(
            description: "Increase Physical damage by \(Int.max).",
            modifiers: [.damageDealt(.physical, Int.max)],
        )
        let powers = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([stored]))
        let item = try ItemFixtures.makeBareItem(
            "double_axe", affixes: [definition.resolved(for: .basic)], affixPowers: powers,
        )
        #expect(item.displayedAffixes.first?.description == "Increase Physical damage by \(Int.max)")
        #expect(item.resolvedPower(at: 0)?.modifiers == stored.modifiers)
        #expect(item.isPerfectAffix(at: 0))
        #expect(stored.bumpCandidates(direction: .up).isEmpty)
        let target = try #require(stored.bumpCandidates(direction: .down).first)
        #expect(stored.bumped(target: target, direction: .down).modifiers == [.damageDealt(.physical, Int.max - 1)])
        #expect(stored.rolledMax().modifiers == stored.modifiers)
    }

    @Test(arguments: ["leeching", "shredding"])
    func `large saved percentage powers remain inspectable`(affixID: String) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: affixID))
        var triggers = CombatTraitTriggers()
        triggers.physicalIgnoreMitigationPercent = affixID == "shredding" ? 1e18 : 0
        let modifiers: [AffixModifier] = affixID == "leeching" ? [.leechGainedPercent(1e18)] : []
        let stored = ItemAffixPower(description: "Saved power", modifiers: modifiers, triggers: triggers)
        let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([stored]))
        let item = try ItemFixtures.makeBareItem(
            "dagger", affixes: [definition.resolved(for: .basic)], affixPowers: decoded,
        )
        let power = try #require(item.resolvedPower(at: 0))
        #expect(power.description.contains(String(Int.max)))
        #expect(item.displayedAffixes.first?.description == power.description)
        #expect(item.affixPowers == decoded)
    }

    @Test func `corruption rejects percentage bumps smaller than representable precision`() {
        let stored = ItemAffixPower(description: "Increase Dodge by 100000000000000000000%.", modifiers: [.dodgeChanceBonus(1e18)])
        #expect(stored.bumpCandidates(direction: .up).isEmpty)
        #expect(stored.bumpCandidates(direction: .down).isEmpty)
        #expect(stored.bumped(target: .modifier(0), direction: .up) == stored)
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
