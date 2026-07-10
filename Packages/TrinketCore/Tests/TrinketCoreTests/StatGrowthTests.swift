import Testing
@testable import TrinketCore

@Suite
struct StatGrowthTests {
    @Test func playerGrowthAtLevelOneIsZero() throws {
        let growth = StatGrowth.playerGrowth(archetype: .tank, levelsAbove: 0)
        try #expect(growth == .zero)
    }

    @Test func playerGrowthAddsBaseHealthEveryLevel() throws {
        let growth = StatGrowth.playerGrowth(archetype: .assassin, levelsAbove: 4)
        try #expect(growth.maxHealth == 4)
    }

    @Test func mageGrowthAddsIntellectAndMana() throws {
        let growth = StatGrowth.playerGrowth(archetype: .mage, levelsAbove: 5)
        try #expect(growth.intellect == 5)
        try #expect(growth.maxMana == 2)
    }

    @Test func nonBossEnemyGrowthMatchesPlayerGrowth() throws {
        let player = StatGrowth.playerGrowth(archetype: .bruiser, levelsAbove: 4)
        let enemy = StatGrowth.enemyGrowth(
            archetype: .bruiser,
            isBoss: false,
            levelsAbove: 4,
            identityStats: PrimaryStats(strength: 5, agility: 4, toughness: 4, intellect: 2, wisdom: 2)
        )
        try #expect(enemy == player)
    }

    @Test func bossGrowthSpikesPrimaryStat() throws {
        let stats = PrimaryStats(strength: 12, agility: 2, toughness: 14, intellect: 2, wisdom: 3)
        let growth = StatGrowth.enemyGrowth(
            archetype: .tank,
            isBoss: true,
            levelsAbove: 3,
            identityStats: stats
        )
        try #expect(growth.toughness == 3)
        try #expect(growth.strength == 1)
        try #expect(growth.maxHealth == 5)
    }

    @Test func enemyGearCompensationScalesSmoothlyWithLevel() throws {
        let stats = PrimaryStats(strength: 5, agility: 7, toughness: 5, intellect: 2, wisdom: 5)

        let earlyFodder = StatGrowth.enemyGearCompensation(level: 10, identityStats: stats)
        let midFodder = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats)
        let lateFodder = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats)
        try #expect(earlyFodder.healthMultiplier < midFodder.healthMultiplier)
        try #expect(midFodder.healthMultiplier < lateFodder.healthMultiplier)
        try #expect(earlyFodder.primaryStatMultiplier < lateFodder.primaryStatMultiplier)

        let midBoss = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isBoss: true)
        let lateBoss = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isBoss: true)
        try #expect(midBoss.healthMultiplier > lateBoss.healthMultiplier)
        try #expect(midBoss.primaryStatMultiplier < lateBoss.primaryStatMultiplier)
        try #expect(lateBoss.healthMultiplier < lateFodder.healthMultiplier)

        let midElite = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isElite: true)
        let lateElite = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isElite: true)
        try #expect(midElite.healthMultiplier > lateElite.healthMultiplier)
        try #expect(lateElite.healthMultiplier < lateFodder.healthMultiplier)
    }

    @Test func applyMergesGrowthIntoStats() throws {
        let applied = StatGrowth.apply(
            maxHealth: 14,
            maxMana: 8,
            primaryStats: PrimaryStats(strength: 2, agility: 4, toughness: 3, intellect: 10, wisdom: 3),
            growth: StatGrowthDelta(intellect: 2, maxHealth: 3, maxMana: 1)
        )
        try #expect(applied.maxHealth == 17)
        try #expect(applied.maxMana == 9)
        try #expect(applied.primaryStats.intellect == 12)
    }
}
