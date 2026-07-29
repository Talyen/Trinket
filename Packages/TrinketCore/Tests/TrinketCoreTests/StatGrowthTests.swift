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

    @Test func nonBossEnemyGrowthMatchesPlayerPrimariesWithNoFlatHealth() throws {
        let player = StatGrowth.playerGrowth(archetype: .bruiser, levelsAbove: 4)
        let enemy = StatGrowth.enemyGrowth(
            archetype: .bruiser,
            isBoss: false,
            levelsAbove: 4,
            identityStats: PrimaryStats(strength: 5, agility: 4, toughness: 4, intellect: 2, wisdom: 2)
        )
        try #expect(enemy.strength == player.strength)
        try #expect(enemy.agility == player.agility)
        try #expect(enemy.toughness == player.toughness)
        try #expect(enemy.intellect == player.intellect)
        try #expect(enemy.wisdom == player.wisdom)
        try #expect(enemy.maxMana == 0)
        try #expect(player.maxHealth == 4)
        try #expect(enemy.maxHealth == 0)
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
        try #expect(growth.maxHealth == 0)
    }

    @Test func enemyGearCompensationScalesByLevelBand() throws {
        let stats = PrimaryStats(strength: 5, agility: 7, toughness: 5, intellect: 2, wisdom: 5)

        let earlyNormal = StatGrowth.enemyGearCompensation(level: 1, identityStats: stats, isBoss: false)
        try #expect(earlyNormal.healthMultiplier == 1.75)
        try #expect(earlyNormal.primaryStatMultiplier == 1.75)
        let earlyBoss = StatGrowth.enemyGearCompensation(level: 1, identityStats: stats, isBoss: true)
        try #expect(earlyBoss.healthMultiplier == 2.0)
        try #expect(earlyBoss.primaryStatMultiplier == 2.0)

        let midNormal = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isBoss: false)
        try #expect(midNormal.healthMultiplier == 2.1)
        try #expect(midNormal.primaryStatMultiplier == 2.1)
        let midBoss = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isBoss: true)
        try #expect(midBoss.healthMultiplier == 2.25)
        try #expect(midBoss.primaryStatMultiplier == 2.25)

        let lateNormal = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isBoss: false)
        try #expect(lateNormal.healthMultiplier == 2.4)
        try #expect(lateNormal.primaryStatMultiplier == 2.4)
        let lateBoss = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isBoss: true)
        try #expect(lateBoss.healthMultiplier == 2.5)
        try #expect(lateBoss.primaryStatMultiplier == 2.5)
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
