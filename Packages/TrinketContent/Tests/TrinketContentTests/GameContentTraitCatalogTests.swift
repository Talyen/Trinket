import Testing
import TrinketCore
@testable import TrinketContent

struct GameContentTraitCatalogTests {
    @Test func everyEnemyReferencesKnownTrait() throws {
        let traitIDs = Set(GameContent.traits.map(\.id))
        for enemy in GameContent.enemies {
            try #expect(traitIDs.contains(enemy.traitID), "\(enemy.name) trait")
        }
    }

    @Test func enemyTraitsAreCatalogSourced() throws {
        try #expect(GameContent.traits.count == GameContent.enemies.count)
    }

    @Test func everyHeroAndCompanionHasSignatureTalentNode() throws {
        let combatants = GameContent.heroes + GameContent.companions
        for combatant in combatants {
            let config = CombatantTalentCatalog.config(for: combatant.id)
            let nodeIDs = Set(config.trees.flatMap(\.nodes).map(\.id))
            let matchingSignature = CombatantTalentCatalog.signatureTalents.keys.filter { $0.hasPrefix("\(combatant.id)_") }
            try #expect(!matchingSignature.isEmpty, "Missing signature talent for \(combatant.id)")
            for sigID in matchingSignature {
                try #expect(nodeIDs.contains(sigID), "\(sigID) not found in trees for \(combatant.id)")
                let effect = CombatantTalentCatalog.signatureTalents[sigID]
                try #expect(effect != nil)
                try #expect(!(effect?.name.isEmpty ?? true))
                try #expect(!(effect?.description.isEmpty ?? true))
            }
        }
    }

    @Test func traitDescriptionsAreNonEmpty() throws {
        for trait in GameContent.traits {
            try #expect(!trait.name.isEmpty, "Trait \(trait.id) needs a name")
            try #expect(!trait.description.isEmpty, "Trait \(trait.id) needs a description")
        }
    }

    @Test func traitIDsAreUnique() throws {
        let ids = GameContent.traits.map(\.id)
        try #expect(ids.count == Set(ids).count)
    }
}
