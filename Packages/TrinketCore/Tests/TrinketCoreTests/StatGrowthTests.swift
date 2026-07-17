import Testing
@testable import TrinketCore

struct StatGrowthTests {
    @Test func playerGrowthCoversBaselineHealthAndArchetypes() throws {
        let growth = StatGrowth.playerGrowth(archetype: .tank, levelsAbove: 0)
        try #expect(growth == .zero)
        let assassinGrowth = StatGrowth.playerGrowth(archetype: .assassin, levelsAbove: 4)
        try #expect(assassinGrowth.maxHealth == 4)
    }

    @Test func mageGrowthAddsIntellectAndOptionalManaByRole() throws {
        let player = StatGrowth.playerGrowth(archetype: .mage, levelsAbove: 5)
        try #expect(player.intellect == 5)
        try #expect(player.maxMana == 2)

        let enemy = StatGrowth.enemyGrowth(
            archetype: .mage,
            isBoss: false,
            levelsAbove: 5,
            identityStats: PrimaryStats(strength: 5, agility: 4, toughness: 4, intellect: 2, wisdom: 2)
        )
        try #expect(enemy.maxMana == 0)
        try #expect(enemy.intellect == 5)
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

        let earlyNormal = StatGrowth.enemyGearCompensation(level: 10, identityStats: stats)
        let midNormal = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats)
        let lateNormal = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats)
        try #expect(earlyNormal.healthMultiplier < midNormal.healthMultiplier)
        try #expect(midNormal.healthMultiplier < lateNormal.healthMultiplier)
        try #expect(earlyNormal.primaryStatMultiplier < lateNormal.primaryStatMultiplier)

        let midBoss = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isBoss: true)
        let lateBoss = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isBoss: true)
        try #expect(midBoss.healthMultiplier > lateBoss.healthMultiplier)
        try #expect(midBoss.primaryStatMultiplier < lateBoss.primaryStatMultiplier)
        try #expect(lateBoss.healthMultiplier < lateNormal.healthMultiplier)
    }

    @Test func enemyPrimaryStatMultiplierStaysModestVsPlayerGrowth() throws {
        let assassinStats = PrimaryStats(strength: 3, agility: 8, toughness: 3, intellect: 2, wisdom: 2)
        let late = StatGrowth.enemyGearCompensation(level: 50, identityStats: assassinStats)
        // Keep primary-stat inflation well below historical ~2x so matched-level
        // Assassin enemies stay near player Assassin Agility.
        try #expect(late.primaryStatMultiplier < 1.25)
        try #expect(late.primaryStatMultiplier > 1.0)
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
