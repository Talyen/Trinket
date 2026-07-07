import Testing
@testable import TrinketContent

@Suite
struct GameContentTraitCatalogTests {
    @Test func everyHeroAndPetReferencesKnownTrait() {
        let traitIDs = Set(GameContent.traits.map(\.id))
        let combatantIDs = GameContent.heroes.map(\.id) + GameContent.pets.map(\.id)

        for combatantID in combatantIDs {
            guard let traitID = GameContent.combatantTraitIDs[combatantID] else {
                Issue.record("Missing trait mapping for combatant \(combatantID)")
                continue
            }
            #expect(
                traitIDs.contains(traitID),
                "Combatant \(combatantID) references unknown trait \(traitID)"
            )
        }
    }

    @Test func everyCombatantHasExactlyOneTraitMapping() {
        let combatantIDs = Set(GameContent.heroes.map(\.id) + GameContent.pets.map(\.id))
        #expect(GameContent.combatantTraitIDs.count == combatantIDs.count)
        #expect(Set(GameContent.combatantTraitIDs.keys) == combatantIDs)
    }

    @Test func everyEnemyHasPositiveAndNegativeTraits() {
        let traitIDs = Set(GameContent.traits.map(\.id))
        for enemy in GameContent.enemies {
            #expect(traitIDs.contains(enemy.positiveTraitID), "\(enemy.name) positive trait")
            #expect(traitIDs.contains(enemy.negativeTraitID), "\(enemy.name) negative trait")
            #expect(
                enemy.positiveTraitID != enemy.negativeTraitID,
                "\(enemy.name) should not reuse the same trait"
            )
        }
    }

    @Test func traitDescriptionsAreNonEmpty() {
        for trait in GameContent.traits {
            #expect(!(trait.name.isEmpty, "Trait \(trait.id)) needs a name")
            #expect(!(trait.description.isEmpty, "Trait \(trait.id)) needs a description")
        }
    }

    @Test func traitIDsAreUnique() {
        let ids = GameContent.traits.map(\.id)
        #expect(ids.count == Set(ids).count)
    }
}
