import XCTest
@testable import BattleEngine
import TrinketContent
import TrinketCore

final class CombatantLevelScalerTests: XCTestCase {
    func testPlayerScalerAtLevelOneMatchesIdentity() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let scaled = CombatantLevelScaler.scale(combatant: knight, level: 1)

        XCTAssertEqual(scaled.maxHealth, knight.maxHealth)
        XCTAssertEqual(scaled.primaryStats, knight.primaryStats)
    }

    func testPlayerScalerIncreasesHealthAboveEnemyAtSameLevel() throws {
        let knight = try XCTUnwrap(GameContent.heroes.first { $0.id == "knight" })
        let skeleton = try XCTUnwrap(GameContent.enemy(matching: "skeleton"))
        let level = 5

        let scaledHero = CombatantLevelScaler.scale(combatant: knight, level: level)
        let scaledEnemy = CombatantLevelScaler.scale(enemy: skeleton, level: level)

        XCTAssertGreaterThan(scaledHero.maxHealth, scaledEnemy.maxHealth)
    }

    func testEnemyScalerUsesBossProfile() throws {
        let boss = try XCTUnwrap(GameContent.enemy(matching: "the_forge_golem"))
        let scaled = CombatantLevelScaler.scale(enemy: boss, level: 3)

        XCTAssertEqual(scaled.maxHealth, 53)
        XCTAssertEqual(scaled.primaryStats.toughness, 28)
    }
}
