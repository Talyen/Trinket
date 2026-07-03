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
}
