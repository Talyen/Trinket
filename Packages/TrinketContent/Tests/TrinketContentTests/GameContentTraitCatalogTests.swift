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

    @Test func traitDescriptionsAreNonEmpty() throws {
        for trait in GameContent.traits {
            try #expect(!trait.name.isEmpty, "Trait \(trait.id) needs a name")
            try #expect(!trait.description.isEmpty, "Trait \(trait.id) needs a description")
        }
    }
}
