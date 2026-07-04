import XCTest
import TrinketCore

final class StatGrowthTests: XCTestCase {
    func testPlayerGrowthAtLevelOneIsZero() {
        let growth = StatGrowth.playerGrowth(archetype: .tank, levelsAbove: 0)
        XCTAssertEqual(growth, .zero)
    }

    func testPlayerGrowthAddsBaseHealthEveryLevel() {
        let growth = StatGrowth.playerGrowth(archetype: .assassin, levelsAbove: 4)
        XCTAssertEqual(growth.maxHealth, 4)
    }

    func testMageGrowthAddsIntellectAndMana() {
        let growth = StatGrowth.playerGrowth(archetype: .mage, levelsAbove: 5)
        XCTAssertEqual(growth.intellect, 5)
        XCTAssertEqual(growth.maxMana, 2)
    }

    func testEnemyGrowthMatchesPlayerHealthAtEqualLevel() {
        let player = StatGrowth.playerGrowth(archetype: .bruiser, levelsAbove: 4)
        let enemy = StatGrowth.enemyGrowth(
            archetype: .bruiser,
            isBoss: false,
            levelsAbove: 4,
            identityStats: PrimaryStats(strength: 5, agility: 4, toughness: 4, intellect: 2, wisdom: 2)
        )
        XCTAssertEqual(player.maxHealth, 4)
        XCTAssertEqual(enemy.maxHealth, 4)
    }

    func testBossGrowthSpikesPrimaryStat() {
        let stats = PrimaryStats(strength: 12, agility: 2, toughness: 14, intellect: 2, wisdom: 3)
        let growth = StatGrowth.enemyGrowth(
            archetype: .tank,
            isBoss: true,
            levelsAbove: 3,
            identityStats: stats
        )
        XCTAssertEqual(growth.toughness, 3)
        XCTAssertEqual(growth.strength, 1)
        XCTAssertEqual(growth.maxHealth, 5)
    }

    func testEnemyGearCompensationScalesSmoothlyWithLevel() {
        let stats = PrimaryStats(strength: 5, agility: 7, toughness: 5, intellect: 2, wisdom: 5)

        let earlyFodder = StatGrowth.enemyGearCompensation(level: 10, identityStats: stats)
        let midFodder = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats)
        let lateFodder = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats)
        XCTAssertLessThan(earlyFodder.healthMultiplier, midFodder.healthMultiplier)
        XCTAssertLessThan(midFodder.healthMultiplier, lateFodder.healthMultiplier)
        XCTAssertLessThan(earlyFodder.primaryStatMultiplier, lateFodder.primaryStatMultiplier)

        let midBoss = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isBoss: true)
        let lateBoss = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isBoss: true)
        XCTAssertLessThan(midBoss.healthMultiplier, lateBoss.healthMultiplier)
        XCTAssertLessThan(midBoss.primaryStatMultiplier, lateBoss.primaryStatMultiplier)

        let midElite = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats, isElite: true)
        let lateElite = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats, isElite: true)
        XCTAssertLessThan(midElite.healthMultiplier, lateElite.healthMultiplier)
        XCTAssertGreaterThan(midElite.healthMultiplier, midFodder.healthMultiplier)
    }

    func testApplyMergesGrowthIntoStats() {
        let applied = StatGrowth.apply(
            maxHealth: 14,
            maxMana: 8,
            primaryStats: PrimaryStats(strength: 2, agility: 4, toughness: 3, intellect: 10, wisdom: 3),
            growth: StatGrowthDelta(intellect: 2, maxHealth: 3, maxMana: 1)
        )
        XCTAssertEqual(applied.maxHealth, 17)
        XCTAssertEqual(applied.maxMana, 9)
        XCTAssertEqual(applied.primaryStats.intellect, 12)
    }
}
