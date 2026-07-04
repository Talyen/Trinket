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
        XCTAssertEqual(growth.maxHealth, 8)
    }

    func testEnemyGearCompensationScalesSmoothlyWithLevel() {
        let stats = PrimaryStats(strength: 5, agility: 7, toughness: 5, intellect: 2, wisdom: 5)
        let baseline = StatGrowth.enemyGearCompensation(level: 1, identityStats: stats)
        let early = StatGrowth.enemyGearCompensation(level: 10, identityStats: stats)
        let mid = StatGrowth.enemyGearCompensation(level: 20, identityStats: stats)
        let late = StatGrowth.enemyGearCompensation(level: 40, identityStats: stats)

        XCTAssertEqual(baseline.healthMultiplier, 1.0, accuracy: 0.001)
        XCTAssertEqual(baseline.statDelta, .zero)
        XCTAssertLessThan(baseline.healthMultiplier, early.healthMultiplier)
        XCTAssertLessThan(early.healthMultiplier, mid.healthMultiplier)
        XCTAssertLessThan(mid.healthMultiplier, late.healthMultiplier)
        XCTAssertEqual(late.healthMultiplier, 1.25, accuracy: 0.01)
        XCTAssertLessThan(early.statDelta.toughness, late.statDelta.toughness)
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
