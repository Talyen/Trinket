import XCTest
@testable import Trinket

/// Art catalog cross-references live in the app target because `ArtCatalog` is generated there.
final class ArtCatalogIntegrationTests: XCTestCase {
    func testEveryCatalogAbilityHasArt() {
        for ability in AbilityCatalog.all {
            XCTAssertNotNil(
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

    func testGameContentReferencesResolveInCatalog() {
        let referenced = referencedAbilityIDs()
        for id in referenced {
            XCTAssertNotNil(
                AbilityCatalog.ability(id: id),
                "GameContent references unknown ability id \(id)"
            )
        }
    }

    func testEachHeroAndPetHasArtReference() {
        for hero in GameContent.heroes {
            XCTAssertNotNil(
                ArtCatalog.combatantArtByID[hero.id],
                "\(hero.name) should have an art reference in the catalog"
            )
        }

        for pet in GameContent.pets {
            XCTAssertNotNil(
                ArtCatalog.combatantArtByID[pet.id],
                "\(pet.name) should have an art reference in the catalog"
            )
        }
    }

    func testEachEnemyHasArtReference() {
        for enemy in GameContent.enemies {
            let art = ArtCatalog.combatantArtByID[enemy.id]
            XCTAssertNotNil(art, "\(enemy.name) should have an art reference in the catalog")
        }
    }

    func testEnemyArtInManifest() {
        XCTAssertNotNil(ArtCatalog.combatantArtByID["living_armor"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["mimic"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["mud_elemental"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["necromancer"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["plague_doctor"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["skeleton"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["the_blight_treant"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["the_forge_golem"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["the_frostwarden"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["the_iron_bear"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["goblin"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["fire_elemental"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["frost_elemental"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["slime"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["will_o_wisp"])
    }

    func testPlaceholderEnemyNotInCatalog() {
        XCTAssertNil(ArtCatalog.combatantArtByID["placeholder_enemy"])
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
