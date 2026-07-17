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
        let level = 3
        let scaled = CombatantLevelScaler.scale(enemy: boss, level: level)

        let levelsAbove = StatGrowth.levelsAboveIdentity(level)
        let growth = StatGrowth.enemyGrowth(
            archetype: boss.combatant.growthArchetype,
            isBoss: true,
            levelsAbove: levelsAbove,
            identityStats: boss.combatant.primaryStats
        )
        let grown = StatGrowth.apply(
            maxHealth: boss.combatant.maxHealth,
            maxMana: boss.combatant.maxMana,
            primaryStats: boss.combatant.primaryStats,
            growth: growth
        )
        let expected = StatGrowth.applyEnemyGearCompensation(
            maxHealth: grown.maxHealth,
            maxMana: grown.maxMana,
            primaryStats: grown.primaryStats,
            level: level,
            isBoss: true
        )

        try #expect(scaled.maxHealth == expected.maxHealth)
        try #expect(scaled.primaryStats == expected.primaryStats)
        try #expect(scaled.maxHealth > boss.combatant.maxHealth)
        try #expect(scaled.primaryStats.toughness > boss.combatant.primaryStats.toughness)
    }

    @Test func enemyScalerKeepsManaDisabledAtHigherLevels() throws {
        let mage = try #require(GameContent.enemy(matching: "necromancer"))
        let scaled = CombatantLevelScaler.scale(enemy: mage, level: 10)

        try #expect(scaled.maxMana == 0)
        try #expect(!scaled.hasMana)
    }
}
