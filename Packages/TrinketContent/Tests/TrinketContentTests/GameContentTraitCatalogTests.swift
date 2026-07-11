import Testing
@testable import TrinketContent

struct GameContentTraitCatalogTests {
    @Test func everyHeroAndPetReferencesKnownTrait() throws {
        let traitIDs = Set(GameContent.traits.map(\.id))
        let combatantIDs = GameContent.heroes.map(\.id) + GameContent.pets.map(\.id)

        for combatantID in combatantIDs {
            guard let traitID = GameContent.combatantTraitIDs[combatantID] else {
                Issue.record("Missing trait mapping for combatant \(combatantID)")
                continue
            }
            try #expect(
                traitIDs.contains(traitID),
                "Combatant \(combatantID) references unknown trait \(traitID)"
            )
        }
    }

    @Test func everyCombatantHasExactlyOneTraitMapping() throws {
        let combatantIDs = Set(GameContent.heroes.map(\.id) + GameContent.pets.map(\.id))
        try #expect(GameContent.combatantTraitIDs.count == combatantIDs.count)
        try #expect(Set(GameContent.combatantTraitIDs.keys) == combatantIDs)
    }

    @Test func everyEnemyHasPositiveAndNegativeTraits() throws {
        let traitIDs = Set(GameContent.traits.map(\.id))
        for enemy in GameContent.enemies {
            try #expect(traitIDs.contains(enemy.positiveTraitID), "\(enemy.name) positive trait")
            try #expect(traitIDs.contains(enemy.negativeTraitID), "\(enemy.name) negative trait")
            try #expect(
                enemy.positiveTraitID != enemy.negativeTraitID,
                "\(enemy.name) should not reuse the same trait"
            )
        }
    }

    @Test func traitDescriptionsAreNonEmpty() throws {
        for trait in GameContent.traits {
            try #expect(!trait.name.isEmpty, "Trait \(trait.id)) needs a name")
            try #expect(!trait.description.isEmpty, "Trait \(trait.id)) needs a description")
        }
    }

    @Test func traitIDsAreUnique() throws {
        let ids = GameContent.traits.map(\.id)
        try #expect(ids.count == Set(ids).count)
    }
}
