import XCTest
@testable import Trinket

final class EnemyCatalogTests: XCTestCase {
    private let bossIDs: Set<String> = [
        "the_blight_treant",
        "the_forge_golem",
        "the_frostwarden",
        "the_iron_bear"
    ]

    private let bossBaseHealth: Set<Int> = [24, 26, 27, 28]

    private let eliteIDs: Set<String> = [
        "living_armor",
        "mimic",
        "necromancer",
        "plague_doctor"
    ]

    func testEnemyCount() {
        XCTAssertEqual(GameContent.enemies.count, 15)
    }

    func testBossClassification() {
        for enemy in GameContent.enemies {
            if bossIDs.contains(enemy.id) {
                XCTAssertTrue(enemy.isBoss, "\(enemy.name) should be a boss")
                XCTAssertFalse(enemy.isElite, "\(enemy.name) should not also be elite")
            } else {
                XCTAssertFalse(enemy.isBoss, "\(enemy.name) should not be a boss")
            }
        }
    }

    func testEliteClassification() {
        for enemy in GameContent.enemies {
            if eliteIDs.contains(enemy.id) {
                XCTAssertTrue(enemy.isElite, "\(enemy.name) should be elite")
                XCTAssertFalse(enemy.isBoss, "\(enemy.name) should not be a boss")
            } else if !bossIDs.contains(enemy.id) {
                XCTAssertFalse(enemy.isElite, "\(enemy.name) should not be elite")
            }
        }
    }

    func testIronBearUsesBashAndMoltenBulwark() throws {
        let bear = try XCTUnwrap(GameContent.enemies.first { $0.id == "the_iron_bear" })
        let loadout = bear.combatant.abilityLoadout
        XCTAssertEqual(loadout.basic, .bash)
        XCTAssertEqual(loadout.ultimate, .moltenBulwark)
    }

    func testBlightTreantUsesFangs() throws {
        let treant = try XCTUnwrap(GameContent.enemies.first { $0.id == "the_blight_treant" })
        XCTAssertEqual(treant.combatant.abilityLoadout.basic, .fangs)
    }

    func testEachEnemyHasBasicSkillUltimate() {
        for enemy in GameContent.enemies {
            let loadout = enemy.combatant.abilityLoadout
            XCTAssertNotNil(loadout.basic, "\(enemy.name) should have a basic ability")
            XCTAssertNotNil(loadout.skill, "\(enemy.name) should have a skill ability")
            XCTAssertNotNil(loadout.ultimate, "\(enemy.name) should have an ultimate ability")
        }
    }

    func testEachEnemyHasAuthoredBaseHealth() {
        for enemy in GameContent.enemies {
            if enemy.isBoss {
                XCTAssertTrue(
                    bossBaseHealth.contains(enemy.maxHealth),
                    "\(enemy.name) should use a boss base HP band"
                )
            } else if enemy.isElite {
                XCTAssertGreaterThanOrEqual(enemy.maxHealth, 12, "\(enemy.name) should have elite base HP")
                XCTAssertLessThanOrEqual(enemy.maxHealth, 15, "\(enemy.name) should have elite base HP")
            } else {
                XCTAssertGreaterThanOrEqual(enemy.maxHealth, 11, "\(enemy.name) should have fodder base HP")
                XCTAssertLessThanOrEqual(enemy.maxHealth, 14, "\(enemy.name) should have fodder base HP")
            }
        }
    }

    func testEachEnemyHasGrowthArchetype() {
        for enemy in GameContent.enemies {
            XCTAssertFalse(enemy.combatant.growthArchetype.rawValue.isEmpty)
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

    func testAveragePlayerBaseHealthExceedsFodderEnemyBaseHealth() {
        let heroAverage = Double(GameContent.heroes.map(\.maxHealth).reduce(0, +)) / Double(GameContent.heroes.count)
        let petAverage = Double(GameContent.pets.map(\.maxHealth).reduce(0, +)) / Double(GameContent.pets.count)
        let enemyAverage = Double(
            GameContent.enemies.filter { !$0.isBoss }.map(\.maxHealth).reduce(0, +)
        ) / Double(GameContent.enemies.filter { !$0.isBoss }.count)

        XCTAssertGreaterThan(heroAverage, enemyAverage)
        XCTAssertGreaterThan(petAverage, enemyAverage)
    }
}
