import Foundation
import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import TrinketContent

struct ItemAffixMagnitudeRollTests {
    @Test func `Lingering rolls within its authored modifier ranges and retains saved bounds`() throws {
        let lingering = try #require(GameContent.itemAffixDefinition(matching: "lingering"))
        var rng = SeededRandomNumberGenerator(seed: 53)
        let basic = Set((0 ..< 50).map { _ in lingering.basic.rolled(using: &rng).modifiers })
        let astral = Set((0 ..< 50).map { _ in lingering.astral.rolled(using: &rng).modifiers })
        #expect(basic == [[.bleedDuration(1)]])
        #expect(astral == [[.bleedDuration(1)], [.bleedDuration(2)]])
        #expect(lingering.astral.rolledMin().modifiers == [.bleedDuration(1)])
        #expect(lingering.astral.rolledMax().modifiers == [.bleedDuration(2)])
        #expect(lingering.astral.scaled(by: 2).rolledMax().modifiers == [.bleedDuration(4)])
        let restored = try #require(ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([lingering.astral])).first)
        #expect(restored == lingering.astral)
        #expect(restored.rolledMax().modifiers == [.bleedDuration(2)])

        let old = ItemAffixPower(description: "Bleed lasts 3 additional turns", modifiers: [.bleedDuration(3)])
        let oldPowers = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let savedItem = try ItemFixtures.makeBareItem("crossbow", affixes: [lingering.resolved(for: .astral)], affixPowers: oldPowers)
        #expect(savedItem.resolvedPower(at: 0)?.modifiers == [.bleedDuration(6)])
        #expect(savedItem.affixPowers == oldPowers)
    }

    @Test func `saved modifier ranges follow surviving modifiers when an unknown case is discarded`() throws {
        let lingering = try #require(GameContent.itemAffixDefinition(matching: "lingering"))
        let encoded = try ItemAffixPowerCoding.encode([lingering.astral])
        var powers = try #require(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        var modifiers = try #require(powers[0]["modifiers"] as? [Any])
        modifiers.insert(["futureModifier": ["_0": 1]], at: 0)
        powers[0]["modifiers"] = modifiers
        var ranges = try #require(powers[0]["modifierRollRanges"] as? [String: Any])
        ranges["1"] = ranges.removeValue(forKey: "0")
        powers[0]["modifierRollRanges"] = ranges
        let restored = try #require(ItemAffixPowerCoding.decode(JSONSerialization.data(withJSONObject: powers)).first)
        #expect(restored.modifiers == [.bleedDuration(2)])
        #expect(restored.rolledMax().modifiers == [.bleedDuration(2)])
    }

    @Test(arguments: [(Rarity.basic, "dagger", 1), (.astral, "crossbow", 4)])
    func `saved Shredding gains damage without changing its stored bypass roll`(
        rarity: Rarity, baseID: String, expectedDamage: Int,
    ) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "shredding"))
        let old = ItemAffixPower(
            description: "Old Shredding", modifiers: [.maximumHealth(3)],
            triggers: CombatTraitTriggers { $0.ignoreEnemyMitigationPercent = 0.12 },
        )
        let oldPowers = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let item = try ItemFixtures.makeBareItem(
            baseID,
            rarity: rarity,
            affixes: [definition.resolved(for: rarity)],
            affixPowers: oldPowers,
        )
        let power = try #require(item.resolvedPower(at: 0))
        let multiplier = item.baseType.affixPowerMultiplier
        let unscaledDamage = rarity == .basic ? 1 : 2
        #expect(item.unscaledPower(at: 0)?
            .description == "Deal \(unscaledDamage) bonus Physical damage\nYour Physical damage ignores 12% of enemy damage reduction")
        #expect(power.modifiers.contains(.damageDealt(.physical, expectedDamage)))
        #expect(power.modifiers.contains(.maximumHealth(3 * multiplier)))
        #expect(power.triggers.physicalIgnoreMitigationPercent == 0.12 * Double(multiplier))
        #expect(power.triggers.ignoreEnemyMitigationPercent == 0)
        #expect(power
            .description ==
            "Deal \(expectedDamage) bonus Physical damage\nYour Physical damage ignores \(12 * multiplier)% of enemy damage reduction")
        #expect(item.affixPowers == oldPowers)
    }

    @Test func `new Shredding rolls its damage and retains it on equipped items`() throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "shredding"))
        #expect(definition.basic.rolledMin().modifiers == [.damageDealt(.physical, 1)])
        #expect(definition.basic.rolledMax().modifiers == [.damageDealt(.physical, 2)])
        #expect(definition.astral.rolledMin().modifiers == [.damageDealt(.physical, 1)])
        #expect(definition.astral.rolledMax().modifiers == [.damageDealt(.physical, 3)])
        let item = try ItemFixtures.makeBareItem(
            "crossbow", rarity: .astral, affixes: [definition.resolved(for: .astral)], affixPowers: [definition.astral.rolledMax()],
        )
        let power = try #require(item.resolvedPower(at: 0))
        #expect(power.modifiers == [.damageDealt(.physical, 6)])
        #expect(power.triggers.physicalIgnoreMitigationPercent == 0.6)
        #expect(power.description == "Deal 6 bonus Physical damage\nYour Physical damage ignores 60% of enemy damage reduction")
        let english = ContentCopy.description(power.description, locale: Locale(identifier: "en"))
        let japanese = ContentCopy.description(power.description, locale: Locale(identifier: "ja"))
        #expect(english.values == ["quantity_1": 6, "quantity_2": 60])
        #expect(japanese.values == english.values)
        #expect(japanese.text != english.text)
    }

    @Test func `percentage roll bounds match the selectable values`() throws {
        for points in Array(stride(from: 1, through: 500, by: 7)) + [3999, 4000, 40000] {
            let magnitude = Double(points) / 100
            let power = ItemAffixPower(description: "Saved power", modifiers: [.leechGainedPercent(magnitude)])
            let selectable = ItemAffixMagnitudeRoll.percentValues(around: magnitude)
            let minimum = try #require(selectable.min())
            #expect(power.rolledMin().modifiers == [.leechGainedPercent(minimum)])
            let expected = try #require(selectable.max())
            #expect(power.rolledMax().modifiers == [.leechGainedPercent(expected)])
        }
    }

    @Test(arguments: [1e8, 1e18])
    func `oversized percentage powers preserve strength when rolled`(magnitude: Double) {
        let power = ItemAffixPower(description: "Saved power", modifiers: [.leechGainedPercent(magnitude)])
        var rng = SeededRandomNumberGenerator(seed: 3)
        #expect(power.rolled(using: &rng).modifiers == power.modifiers)
        #expect(power.rolledMin().modifiers == power.modifiers)
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
            triggers: CombatTraitTriggers { $0.leechThornsWithoutThorns = 2 },
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
