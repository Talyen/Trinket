import XCTest
@testable import Trinket

final class EnemyCatalogTests: XCTestCase {
    private let bossIDs: Set<String> = [
        "the_blight_treant",
        "the_forge_golem",
        "the_frostwarden",
        "the_iron_bear",
    ]

    func testEnemyCount() {
        XCTAssertEqual(GameContent.enemies.count, 12)
    }

    func testBossClassification() {
        for enemy in GameContent.enemies {
            if bossIDs.contains(enemy.id) {
                XCTAssertTrue(enemy.isBoss, "\(enemy.name) should be a boss")
            } else {
                XCTAssertFalse(enemy.isBoss, "\(enemy.name) should not be a boss")
            }
        }
    }

    func testEachEnemyHasBasicSkillUltimate() {
        for enemy in GameContent.enemies {
            let loadout = enemy.combatant.abilityLoadout
            XCTAssertNotNil(loadout.basic, "\(enemy.name) should have a basic ability")
            XCTAssertNotNil(loadout.skill, "\(enemy.name) should have a skill ability")
            XCTAssertNotNil(loadout.ultimate, "\(enemy.name) should have an ultimate ability")
        }
    }

    func testEachEnemyHasDefaultLevel() {
        for enemy in GameContent.enemies {
            XCTAssertEqual(enemy.level, Enemy.defaultLevel, "\(enemy.name) should use default level")
        }
    }

    func testEachEnemyHasDefaultHealth() {
        for enemy in GameContent.enemies {
            XCTAssertEqual(enemy.maxHealth, Enemy.defaultMaxHealth, "\(enemy.name) should use default max health")
        }
    }

    func testEachEnemyHasArtReference() {
        for enemy in GameContent.enemies {
            let art = ArtCatalog.combatantArtByID[enemy.id]
            XCTAssertNotNil(art, "\(enemy.name) should have an art reference in the catalog")
        }
    }

    func testEnemyArtInManifest() {
        XCTAssertNotNil(ArtCatalog.combatantArtByID["goblin"])
        XCTAssertNotNil(ArtCatalog.combatantArtByID["imp_enemy"])
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
    }

    func testIDsAreUniqueAcrossCombatants() {
        let allIDs = Set(GameContent.heroes.map(\.id))
            .union(GameContent.pets.map(\.id))
            .union(GameContent.enemies.map(\.id))
        let combinedCount = GameContent.heroes.count + GameContent.pets.count + GameContent.enemies.count
        XCTAssertEqual(allIDs.count, combinedCount, "Hero, pet, and enemy IDs must be globally unique")
    }

    func testPlaceholderEnemyNotInCatalog() {
        XCTAssertNil(ArtCatalog.combatantArtByID["placeholder_enemy"])
    }
}
