import Testing
import TrinketCore
@testable import TrinketContent

struct KeywordCohesionTests {
    @Test func `mechanics name their keywords or general attack scope`() throws {
        var missing: [String] = []
        for ability in AbilityCatalog.all where Keyword.referenced(in: ability.summary).isEmpty {
            missing.append("ability:\(ability.id)")
        }
        for (nodeID, talent) in CombatantTalentCatalog.signatureTalents where Keyword.referenced(in: talent.description).isEmpty {
            missing.append("talent:\(nodeID)")
        }
        for trait in GameContent.traits where Keyword.referenced(in: trait.description).isEmpty {
            // Ambush doubles any attack damage; its former Holy weakness is now a separate trait.
            if trait.id == "ambush" {
                #expect(trait.modifiers.isEmpty)
                #expect(trait.triggers == CombatTraitTriggers { $0.firstHitDoubleDamage = true })
            } else {
                missing.append("trait:\(trait.id)")
            }
        }
        for definition in GameContent.itemAffixDefinitions {
            // Damage-agnostic attack rules do not name a single damage-type keyword.
            if Keyword.referenced(in: definition.basic.description).isEmpty,
               !definition.basic.description.lowercased().contains("attack") {
                missing.append("affix-basic:\(definition.id)")
            }
            if Keyword.referenced(in: definition.astral.description).isEmpty,
               !definition.astral.description.lowercased().contains("attack") {
                missing.append("affix-astral:\(definition.id)")
            }
        }
        for item in GameContent.uniqueItems {
            for affix in item.affixes where affix.id == item.id && Keyword.referenced(in: affix.description).isEmpty {
                missing.append("unique:\(item.id)")
            }
        }
        try #expect(missing.isEmpty, "Missing keywords: \(missing.sorted())")
    }
}
