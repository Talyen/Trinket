@testable import Trinket
import XCTest

final class HeroPetCatalogTests: XCTestCase {
    func testEachHeroHasBasicSkillUltimateChoices() {
        for hero in GameContent.heroes {
            XCTAssertFalse(hero.abilityChoices.basics.isEmpty, "\(hero.name) should have basic choices")
            XCTAssertFalse(hero.abilityChoices.skills.isEmpty, "\(hero.name) should have skill choices")
            XCTAssertFalse(hero.abilityChoices.ultimates.isEmpty, "\(hero.name) should have ultimate choices")
            XCTAssertNotNil(hero.abilityLoadout.basic, "\(hero.name) should have a selected basic")
            XCTAssertNotNil(hero.abilityLoadout.skill, "\(hero.name) should have a selected skill")
            XCTAssertNotNil(hero.abilityLoadout.ultimate, "\(hero.name) should have a selected ultimate")
        }
    }

    func testEachPetHasBasicSkillUltimateChoices() {
        for pet in GameContent.pets {
            XCTAssertFalse(pet.abilityChoices.basics.isEmpty, "\(pet.name) should have basic choices")
            XCTAssertFalse(pet.abilityChoices.skills.isEmpty, "\(pet.name) should have skill choices")
            XCTAssertFalse(pet.abilityChoices.ultimates.isEmpty, "\(pet.name) should have ultimate choices")
            XCTAssertNotNil(pet.abilityLoadout.basic, "\(pet.name) should have a selected basic")
            XCTAssertNotNil(pet.abilityLoadout.skill, "\(pet.name) should have a selected skill")
            XCTAssertNotNil(pet.abilityLoadout.ultimate, "\(pet.name) should have a selected ultimate")
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
}
