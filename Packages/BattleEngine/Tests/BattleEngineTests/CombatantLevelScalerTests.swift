import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CombatantLevelScalerTests {
    @Test func playerScalerAtLevelOneMatchesIdentity() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let scaled = CombatantLevelScaler.scale(combatant: knight, level: 1)

        try #expect(scaled.maxHealth == knight.maxHealth)
        try #expect(scaled.primaryStats == knight.primaryStats)
    }

    @Test func playerScalerIncreasesHealthAboveEnemyAtSameLevel() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))
        let level = 5

        let scaledHero = CombatantLevelScaler.scale(combatant: knight, level: level)
        let scaledEnemy = CombatantLevelScaler.scale(enemy: skeleton, level: level)

        try #expect(scaledHero.maxHealth > scaledEnemy.maxHealth)
    }

    @Test func enemyScalerUsesBossProfile() throws {
        let boss = try #require(GameContent.enemy(matching: "the_forge_golem"))
        let scaled = CombatantLevelScaler.scale(enemy: boss, level: 3)

        try #expect(scaled.maxHealth == 53)
        try #expect(scaled.primaryStats.toughness == 22)
    }

    @Test func enemyScalerKeepsManaDisabledAtHigherLevels() throws {
        let mage = try #require(GameContent.enemy(matching: "necromancer"))
        let scaled = CombatantLevelScaler.scale(enemy: mage, level: 10)

        try #expect(scaled.maxMana == 0)
        try #expect(!scaled.hasMana)
    }
}
