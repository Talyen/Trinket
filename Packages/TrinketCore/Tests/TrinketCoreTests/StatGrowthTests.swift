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

        let enemy = StatGrowth.enemyGrowth(archetype: .mage, levelsAbove: 5)
        try #expect(enemy.maxMana == 0)
        try #expect(enemy.intellect == 5)
    }

    @Test func enemyGrowthMatchesPlayerPrimariesWithNoFlatHealth() throws {
        let player = StatGrowth.playerGrowth(archetype: .bruiser, levelsAbove: 4)
        let enemy = StatGrowth.enemyGrowth(archetype: .bruiser, levelsAbove: 4)
        try #expect(enemy.strength == player.strength)
        try #expect(enemy.agility == player.agility)
        try #expect(enemy.toughness == player.toughness)
        try #expect(enemy.intellect == player.intellect)
        try #expect(enemy.wisdom == player.wisdom)
        try #expect(enemy.maxMana == 0)
        try #expect(player.maxHealth == 4)
        try #expect(enemy.maxHealth == 0)
    }

    @Test func applyPowerMultiplierScalesHealthAndStats() throws {
        let stats = PrimaryStats(strength: 10, agility: 8, toughness: 12, intellect: 6, wisdom: 14)
        let applied = StatGrowth.applyPowerMultiplier(
            maxHealth: 12,
            maxMana: 0,
            primaryStats: stats,
            multiplier: 2.0
        )
        try #expect(applied.maxHealth == 24)
        try #expect(applied.primaryStats.strength == 20)
        try #expect(applied.primaryStats.toughness == 24)
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
