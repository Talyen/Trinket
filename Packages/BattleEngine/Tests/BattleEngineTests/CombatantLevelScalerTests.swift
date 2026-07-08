import Testing
@testable import BattleEngine
import TrinketContent
import TrinketCore

@Suite
struct CombatantLevelScalerTests {
    @Test func playerScalerAtLevelOneMatchesIdentity() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let scaled = CombatantLevelScaler.scale(combatant: knight, level: 1)

        #expect(scaled.maxHealth == knight.maxHealth)
        #expect(scaled.primaryStats == knight.primaryStats)
    }

    @Test func playerScalerIncreasesHealthAboveEnemyAtSameLevel() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))
        let level = 5

        let scaledHero = CombatantLevelScaler.scale(combatant: knight, level: level)
        let scaledEnemy = CombatantLevelScaler.scale(enemy: skeleton, level: level)

        #expect(scaledHero.maxHealth > scaledEnemy.maxHealth)
    }

    @Test func enemyScalerUsesBossProfile() throws {
        let boss = try #require(GameContent.enemy(matching: "the_forge_golem"))
        let scaled = CombatantLevelScaler.scale(enemy: boss, level: 3)

        #expect(scaled.maxHealth == 53)
        #expect(scaled.primaryStats.toughness == 28)
    }
}
