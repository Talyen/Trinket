import XCTest
@testable import TrinketContent

final class ArtCatalogIntegrationTests: XCTestCase {
    func testEveryCatalogAbilityHasArt() throws {
        for ability in AbilityCatalog.all {
            _ = try XCTUnwrap(
                ability.artReference,
                "Missing art for ability id \(ability.id)"
            )
        }
    }

    func testArtCatalogOnlyReferencesKnownAbilities() {
        let catalogIDs = Set(AbilityCatalog.all.map(\.id))
        let artIDs = Set(ArtCatalog.abilityArtByID.keys)
        let unknownArtIDs = artIDs.subtracting(catalogIDs)
        XCTAssertTrue(
            unknownArtIDs.isEmpty,
            "Art catalog references unknown ability IDs: \(unknownArtIDs.sorted())"
        )
    }

    func testGameContentReferencesResolveInCatalog() throws {
        let referenced = referencedAbilityIDs()
        for id in referenced {
            _ = try XCTUnwrap(
                AbilityCatalog.ability(id: id),
                "GameContent references unknown ability id \(id)"
            )
        }
    }

    func testEachHeroAndPetHasArtReference() throws {
        for hero in GameContent.heroes {
            _ = try XCTUnwrap(
                ArtCatalog.combatantArtByID[hero.id],
                "\(hero.name) should have an art reference in the catalog"
            )
        }

        for pet in GameContent.pets {
            _ = try XCTUnwrap(
                ArtCatalog.combatantArtByID[pet.id],
                "\(pet.name) should have an art reference in the catalog"
            )
        }
    }

    func testEachEnemyHasArtReference() throws {
        for enemy in GameContent.enemies {
            _ = try XCTUnwrap(
                ArtCatalog.combatantArtByID[enemy.id],
                "\(enemy.name) should have an art reference in the catalog"
            )
        }
    }

    func testEncounterArtReferencesExistInCatalog() throws {
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                guard let artID = GameContent.encounterArtID(for: stage) else { continue }
                _ = try XCTUnwrap(
                    ArtCatalog.encounterArtByID[artID],
                    "Stage \(stage.id) references missing encounter art \(artID)"
                )
            }
        }
    }

    private func referencedAbilityIDs() -> Set<String> {
        var ids = Set<String>()
        let combatants = GameContent.heroes + GameContent.pets + GameContent.enemies.map(\.combatant)
        for combatant in combatants {
            for ability in combatant.abilityChoices.basics + combatant.abilityChoices.skills + combatant.abilityChoices.ultimates {
                ids.insert(ability.id)
            }
            for ability in combatant.abilityLoadout.abilities {
                ids.insert(ability.id)
            }
        }
        return ids
    }
}
