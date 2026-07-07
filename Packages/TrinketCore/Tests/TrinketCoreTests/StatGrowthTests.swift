import Testing
@testable import TrinketCore

@Suite
struct StatGrowthTests {
    @Test func playerGrowthAtLevelOneIsZero() {
        let growth = StatGrowth.playerGrowth(archetype: .tank, levelsAbove: 0)
        #expect(growth == .zero)
    }

    @Test func playerGrowthAddsBaseHealthEveryLevel() {
        let growth = StatGrowth.playerGrowth(archetype: .assassin, levelsAbove: 4)
        #expect(growth.maxHealth == 4)
    }

    @Test func mageGrowthAddsIntellectAndMana() {
        let growth = StatGrowth.playerGrowth(archetype: .mage, levelsAbove: 5)
        #expect(growth.intellect == 5)
        #expect(growth.maxMana == 2)
    }

    @Test func enemyGrowthMatchesPlayerHealthAtEqualLevel() {
        let player = StatGrowth.playerGrowth(archetype: .bruiser, levelsAbove: 4)
        let enemy = StatGrowth.enemyGrowth(
            archetype: .bruiser,
            isBoss: false,
            levelsAbove: 4,
            identityStats: PrimaryStats(strength: 5, agility: 4, toughness: 4, intellect: 2, wisdom: 2)
        )
        #expect(player.maxHealth == 4)
        #expect(enemy.maxHealth == 4)
    }

    @Test func bossGrowthSpikesPrimaryStat() {
        let stats = PrimaryStats(strength: 12, agility: 2, toughness: 14, intellect: 2, wisdom: 3)
        let growth = StatGrowth.enemyGrowth(
            archetype: .tank,
            isBoss: true,
            levelsAbove: 3,
            identityStats: stats
        )
        #expect(growth.toughness == 3)
        #expect(growth.strength == 1)
        #expect(growth.maxHealth == 5)
    }

    @Test func enemyGearCompensationScalesSmoothlyWithLevel() {
        let stats = PrimaryStats(strength: 5, agility: 7, toughness: 5, intellect: 2, wisdom: 5)

        let earlyFodder = StatGrowth.enemyGearCompensation(level: 10, identityStats: stats)
        let midFodder = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats)
        let lateFodder = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats)
        #expect(earlyFodder.healthMultiplier < midFodder.healthMultiplier)
        #expect(midFodder.healthMultiplier < lateFodder.healthMultiplier)
        #expect(earlyFodder.primaryStatMultiplier < lateFodder.primaryStatMultiplier)

        let midBoss = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isBoss: true)
        let lateBoss = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isBoss: true)
        #expect(midBoss.healthMultiplier > lateBoss.healthMultiplier)
        #expect(midBoss.primaryStatMultiplier < lateBoss.primaryStatMultiplier)
        #expect(lateBoss.healthMultiplier < lateFodder.healthMultiplier)

        let midElite = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isElite: true)
        let lateElite = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isElite: true)
        #expect(midElite.healthMultiplier > lateElite.healthMultiplier)
        #expect(lateElite.healthMultiplier < lateFodder.healthMultiplier)
    }

    @Test func applyMergesGrowthIntoStats() {
        let applied = StatGrowth.apply(
            maxHealth: 14,
            maxMana: 8,
            primaryStats: PrimaryStats(strength: 2, agility: 4, toughness: 3, intellect: 10, wisdom: 3),
            growth: StatGrowthDelta(intellect: 2, maxHealth: 3, maxMana: 1)
        )
        #expect(applied.maxHealth == 17)
        #expect(applied.maxMana == 9)
        #expect(applied.primaryStats.intellect == 12)
    }
}
