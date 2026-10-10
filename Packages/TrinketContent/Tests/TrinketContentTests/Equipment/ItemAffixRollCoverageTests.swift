import Testing
import TrinketCore
@testable import TrinketContent

/// Pins the affix rolling contract: every trigger magnitude an affix populates
/// must roll with the loot system or be explicitly excused, and every rollable
/// power must display its rolls.
struct ItemAffixRollCoverageTests {
    @Test func `scaling binds numbers before any replacement can collide`() {
        let power = ItemAffixPower(
            description: "Gain 1 Block and 2 Health with 10% Dodge and 20% damage.",
            modifiers: [.blockGained(1), .maximumHealth(2), .dodgeChanceBonus(0.10), .outgoingDamagePercent(0.20)],
        )
        let scaled = power.scaled(by: 2)
        #expect(scaled.modifiers == [.blockGained(2), .maximumHealth(4), .dodgeChanceBonus(0.20), .outgoingDamagePercent(0.40)])
        #expect(scaled.description == "Gain 2 Block and 4 Health with 20% Dodge and 40% damage.")
    }

    @Test func `corruption changes the selected field when magnitudes are equal`() throws {
        let power = ItemAffixPower(
            description: "Gain 2 Block and deal 2 Poison damage.",
            modifiers: [.blockGained(2)],
            triggers: CombatTraitTriggers(dot: DotTriggers(onBleedApplyPoison: 2)),
        )
        let target = try #require(power.bumpCandidates(direction: .up).last)
        let bumped = power.bumped(target: target, direction: .up)
        #expect(bumped.modifiers == power.modifiers)
        #expect(bumped.triggers.onBleedApplyPoison == 3)
        #expect(bumped.description == "Gain 2 Block and deal 3 Poison damage.")
    }

    @Test func `unchanged roll still reserves its description number`() {
        let power = ItemAffixPower(
            description: "Gain 2 Block and 2 Health.",
            modifiers: [.blockGained(2), .maximumHealth(2)],
        )
        var rng = SeededRandomNumberGenerator(seed: 4)
        let rolled = power.rolled(using: &rng)
        #expect(rolled.modifiers == [.blockGained(2), .maximumHealth(3)])
        #expect(rolled.description == "Gain 2 Block and 3 Health.")
    }

    @Test func `bumping damage never changes the health threshold or percentage token`() throws {
        let executioners = try #require(GameContent.itemAffixDefinition(matching: "executioners"))
        let target = try #require(executioners.basic.bumpCandidates(direction: .up).first)
        let bumped = executioners.basic.bumped(target: target, direction: .up)
        #expect(bumped.triggers.damageBelowHealthPercentThreshold == 0.30)
        #expect(bumped.triggers.damageBelowHealthPercentBonus == 3)
        #expect(bumped.description == "Deal 3 additional damage if the enemy is below 30% Health.")

        let power = ItemAffixPower(
            description: "Gain 20 Strength when below 20% Health.",
            modifiers: [.maximumHealth(20)],
        )
        let increased = power.bumped(target: .modifier(0), direction: .up)
        #expect(increased.modifiers == [.maximumHealth(21)])
        #expect(increased.description == "Gain 21 Strength when below 20% Health.")
    }

    @Test func `minimum integer and percent magnitudes cannot be reduced`() {
        for power in [
            ItemAffixPower(description: "Gain 1 Health.", modifiers: [.maximumHealth(1)]),
            ItemAffixPower(description: "Gain 1% more Gold.", modifiers: [.goldGainedPercent(0.01)]),
        ] {
            #expect(power.bumpCandidates(direction: .down).isEmpty)
            #expect(power.bumped(target: .modifier(0), direction: .down) == power)
        }
    }

    @Test func `percentage trigger bumps preserve the power and displayed magnitude`() throws {
        let power = ItemAffixPower(
            description: "Gain 25% Thorns.",
            triggers: CombatTraitTriggers(mitigation: MitigationTriggers(thornsPercent: 0.25)),
        )
        let target = try #require(power.bumpCandidates(direction: .up).first)
        let increased = power.bumped(target: target, direction: .up)
        #expect(abs(increased.triggers.thornsPercent - 0.26) < 1e-9)
        #expect(increased.description == "Gain 26% Thorns.")
        #expect(increased.bumped(target: target, direction: .down) == power)
    }

    @Test func `every populated affix trigger field rolls or is excused`() {
        let rollable = CombatTraitTriggers.affixMagnitudeFieldNames
        var violations: [String] = []
        for definition in GameContent.itemAffixDefinitions {
            for power in [definition.basic, definition.astral] {
                for field in power.triggers.populatedFieldNames {
                    if !rollable.contains(field), CombatTraitTriggers.nonRollableAffixFields[field] == nil {
                        violations.append("\(definition.id): \(field)")
                    }
                }
            }
        }
        #expect(violations.isEmpty, "Classify affix_roll in the trigger schema: \(violations.sorted())")
    }

    @Test func `every rollable generatable power displays its roll max`() {
        // Trinkets are authored singletons (basic == astral, never generated or
        // rolled); their word-described magnitudes ("half", "equal", "a card")
        // are curated display text outside the roll contract.
        var silent: [String] = []
        for definition in GameContent.itemAffixDefinitions where definition.slot != .trinket {
            for power in [definition.basic, definition.astral] {
                guard power.hasRollableMagnitudes else { continue }
                if power.rolledMax().description == power.description {
                    silent.append(definition.id)
                }
            }
        }
        #expect(silent.isEmpty, "Roll max must change card text: \(silent.sorted())")
    }

    @Test func `infected rolls both damage and chance to max`() throws {
        let infected = try #require(GameContent.itemAffixDefinition(matching: "infected"))
        let max = infected.basic.rolledMax()
        #expect(max.triggers.onBleedApplyPoison == 2)
        #expect(abs(max.triggers.onBleedDealPoisonChancePercent - 0.25) < 1e-9)
        #expect(max.description == "Bleed damage: 25% chance to deal 2 Poison damage once per turn.")
    }

    @Test func `mixed modifier and trigger magnitudes share the transformation order`() {
        let power = ItemAffixPower(
            description: "Gain 2 Block and deal 1 Poison damage with a 35% chance.",
            modifiers: [.blockGained(2)],
            triggers: CombatTraitTriggers(dot: DotTriggers(
                onBleedApplyPoison: 1,
                onBleedDealPoisonChancePercent: 0.35,
            )),
        )

        let scaled = power.scaled(by: 2)
        #expect(scaled.modifiers == [.blockGained(4)])
        #expect(scaled.triggers.onBleedApplyPoison == 2)
        #expect(abs(scaled.triggers.onBleedDealPoisonChancePercent - 0.70) < 1e-9)
        #expect(scaled.description == "Gain 4 Block and deal 2 Poison damage with a 70% chance.")

        let max = power.rolledMax()
        #expect(max.modifiers == [.blockGained(3)])
        #expect(max.triggers.onBleedApplyPoison == 2)
        #expect(abs(max.triggers.onBleedDealPoisonChancePercent - 0.40) < 1e-9)
        #expect(max.description == "Gain 3 Block and deal 2 Poison damage with a 40% chance.")
        #expect(max.isAtOrAboveRollMax(of: power))
    }

    @Test(arguments: ["absolving", "nullifying", "disrupting", "unmaking", "spellrending"])
    func `single status removal displays plural count at roll max`(id: String) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: id))
        let noun = id == "absolving" ? "debuff" : "buff"
        #expect(definition.basic.description.contains("a \(noun)"))
        #expect(definition.basic.rolledMax().description.contains("2 \(noun)s"))
        #expect(definition.basic.scaled(by: 3).description.contains("3 \(noun)s"))
    }

    @Test func `status removal bump restores singular wording`() throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "nullifying"))
        let target = try #require(definition.basic.bumpCandidates(direction: .up).first)
        let increased = definition.basic.bumped(target: target, direction: .up)
        #expect(increased.triggers.holyDamagePurgeCount == 2)
        #expect(increased.description == "Purge 2 buffs when you deal Holy damage.")
        let decreased = increased.bumped(target: target, direction: .down)
        #expect(decreased == definition.basic)
    }

    @Test func `status quantity follows earlier modifier magnitude`() {
        let power = ItemAffixPower(
            description: "Gain 1 Block and Purge a buff.",
            modifiers: [.blockGained(1)],
            triggers: CombatTraitTriggers(cleanse: CleanseTriggers(holyDamagePurgeCount: 1)),
        )
        let max = power.rolledMax()
        #expect(max.modifiers == [.blockGained(2)])
        #expect(max.triggers.holyDamagePurgeCount == 2)
        #expect(max.description == "Gain 2 Block and Purge 2 buffs.")
    }

    @Test func `sundering charm stays frozen to match its wording`() throws {
        let sundering = try #require(GameContent.itemAffixDefinition(matching: "sundering_charm"))
        #expect(!sundering.basic.hasRollableMagnitudes)
        #expect(sundering.basic.rolledMax() == sundering.basic)
    }
}
