import XCTest
import TrinketContent

final class CombatantCatalogTests: XCTestCase {
    func testHeroIDsAreUnique() {
        let ids = GameContent.heroes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPetIDsAreUnique() {
        let ids = GameContent.pets.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEnemyIDsAreUnique() {
        let ids = GameContent.enemies.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testBattleStagesReferenceKnownEnemies() {
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                if let enemyID = stage.encounter.battleEnemyID {
                    XCTAssertNotNil(
                        GameContent.enemy(matching: enemyID),
                        "Stage \(stage.id) references unknown enemy \(enemyID)"
                    )
                }
            }
        }
    }

    func testHomesteadNodeIDsAreUnique() {
        let ids = GameContent.homesteadNodes.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testHomesteadPrerequisitesReferenceKnownNodes() {
        let knownIDs = Set(GameContent.homesteadNodes.map(\.id))
        for node in GameContent.homesteadNodes {
            for requirement in node.prerequisites {
                XCTAssertTrue(
                    knownIDs.contains(requirement.nodeID),
                    "Node \(node.id) references unknown prerequisite \(requirement.nodeID)"
                )
            }
        }
    }

    func testHomesteadNodeCatalogMatchesDefinitions() {
        for node in GameContent.homesteadNodes {
            XCTAssertEqual(HomesteadNodeCatalog.maxTierByNodeID[node.id], node.maxTier)
        }
    }

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
}
