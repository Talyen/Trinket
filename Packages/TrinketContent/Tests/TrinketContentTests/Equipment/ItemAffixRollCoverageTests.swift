import Testing
@testable import TrinketContent

/// Pins the affix rolling contract: every trigger magnitude an affix populates
/// must roll with the loot system or be explicitly excused, and every rollable
/// power must display its rolls.
struct ItemAffixRollCoverageTests {
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
        #expect(abs(max.triggers.onBleedDealPoisonChancePercent - 0.40) < 1e-9)
        #expect(max.description == "Dealing Bleed damage has a 40% chance to deal 2 Poison damage.")
    }

    @Test func `sundering charm stays frozen to match its wording`() throws {
        let sundering = try #require(GameContent.itemAffixDefinition(matching: "sundering_charm"))
        #expect(!sundering.basic.hasRollableMagnitudes)
        #expect(sundering.basic.rolledMax() == sundering.basic)
    }
}
