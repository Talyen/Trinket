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

    @Test func playerAndEnemyScalerIncreaseHealthAboveIdentityLevel() throws {
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))
        let level = 5

        let scaledHero = CombatantLevelScaler.scale(combatant: knight, level: level)
        let scaledEnemy = CombatantLevelScaler.scale(enemy: skeleton, level: level)

        try #expect(scaledHero.maxHealth > knight.maxHealth)
        try #expect(scaledEnemy.maxHealth > skeleton.combatant.maxHealth)
    }

    @Test func enemyScalerAppliesSplitHealthAndStatMultipliers() throws {
        let boss = try #require(GameContent.enemy(matching: "the_forge_golem"))
        let level = 20
        let scaled = CombatantLevelScaler.scale(enemy: boss, level: level)
        let health = EnemyPowerCurve.health(level: level, isBoss: true)
        let stats = EnemyPowerCurve.stats(level: level, isBoss: true)

        let levelsAbove = StatGrowth.levelsAboveIdentity(level)
        let growth = StatGrowth.enemyGrowth(
            archetype: boss.combatant.growthArchetype,
            levelsAbove: levelsAbove
        )
        let grown = StatGrowth.apply(
            maxHealth: boss.combatant.maxHealth,
            maxMana: boss.combatant.maxMana,
            primaryStats: boss.combatant.primaryStats,
            growth: growth
        )
        let expected = StatGrowth.applyPowerMultiplier(
            maxHealth: grown.maxHealth,
            maxMana: grown.maxMana,
            primaryStats: grown.primaryStats,
            healthMultiplier: health,
            statsMultiplier: stats
        )
        let uniformStats = StatGrowth.applyPowerMultiplier(
            maxHealth: grown.maxHealth,
            maxMana: grown.maxMana,
            primaryStats: grown.primaryStats,
            healthMultiplier: stats,
            statsMultiplier: stats
        )

        try #expect(health > stats)
        try #expect(scaled.primaryStats == expected.primaryStats)
        try #expect(scaled.maxHealth == expected.maxHealth)
        try #expect(scaled.maxHealth > uniformStats.maxHealth)
        try #expect(scaled.primaryStats == uniformStats.primaryStats)
    }

    @Test func enemyScalerAppliesPowerCurve() throws {
        let boss = try #require(GameContent.enemy(matching: "the_forge_golem"))
        let level = 3
        let scaled = CombatantLevelScaler.scale(enemy: boss, level: level)

        let levelsAbove = StatGrowth.levelsAboveIdentity(level)
        let growth = StatGrowth.enemyGrowth(
            archetype: boss.combatant.growthArchetype,
            levelsAbove: levelsAbove
        )
        let grown = StatGrowth.apply(
            maxHealth: boss.combatant.maxHealth,
            maxMana: boss.combatant.maxMana,
            primaryStats: boss.combatant.primaryStats,
            growth: growth
        )
        let expected = StatGrowth.applyPowerMultiplier(
            maxHealth: grown.maxHealth,
            maxMana: grown.maxMana,
            primaryStats: grown.primaryStats,
            healthMultiplier: EnemyPowerCurve.health(level: level, isBoss: true),
            statsMultiplier: EnemyPowerCurve.stats(level: level, isBoss: true)
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

    @Test func powerRatingReflectsScaledEnemy() throws {
        let skeleton = try #require(GameContent.enemy(matching: "skeleton"))
        let snapshot = CombatantLevelScaler.powerRating(for: skeleton, level: 5)
        let scaled = CombatantLevelScaler.scale(enemy: skeleton, level: 5)

        try #expect(snapshot.level == 5)
        try #expect(snapshot.maxHealth == scaled.maxHealth)
        let statTotal = scaled.primaryStats.strength
            + scaled.primaryStats.agility
            + scaled.primaryStats.toughness
            + scaled.primaryStats.intellect
            + scaled.primaryStats.wisdom
        try #expect(snapshot.rating == scaled.maxHealth + statTotal)
    }
}
