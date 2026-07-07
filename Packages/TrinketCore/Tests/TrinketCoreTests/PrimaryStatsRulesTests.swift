import TrinketCore
import XCTest

final class PrimaryStatsRulesTests: XCTestCase {
    func testStatBonusForDamageUsesCorrectStat() {
        let stats = PrimaryStats(strength: 10, agility: 15, intellect: 20, wisdom: 25)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .physical), 2)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .stun), 2)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .bleed), 3)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .burn), 4)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .freeze), 4)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .poison), 5)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .holy), 5)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .nature), 5)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .armor), 0)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .block), 0)
    }

    func testDodgeChanceCapsAtSeventyFivePercent() {
        XCTAssertEqual(PrimaryStats(agility: 0).dodgeChance, 0.05, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 10).dodgeChance, 0.10, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 100).dodgeChance, 0.55, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 1000).dodgeChance, 0.75, accuracy: 0.0001)
    }

    func testToughnessMitigationPctMatchesFormula() {
        XCTAssertEqual(PrimaryStats(toughness: 0).toughnessMitigationPct, 0.0, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 50).toughnessMitigationPct, 0.5, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 100).toughnessMitigationPct, 100.0 / 150.0, accuracy: 0.0001)
    }

    func testControlMeterThresholdScalesWithAgility() {
        XCTAssertEqual(PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: 100), 20)
        XCTAssertEqual(PrimaryStats(agility: 20).controlMeterThreshold(baseMaxHealth: 101), 25)
    }

    func testCriticalChanceUsesBaseAndStatScaling() {
        XCTAssertEqual(PrimaryStats().criticalChance(for: .physical), 0.05, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 20).criticalChance(for: .physical), 0.10, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(intellect: 20).criticalChance(for: .burn), 0.10, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(wisdom: 20).criticalChance(for: .holy), 0.10, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(agility: 1000).criticalChance(for: .physical), 0.75, accuracy: 0.0001)
    }

    func testControlMeterThresholdUsesCeilOfTwentyPercentMaxHealth() {
        let cases: [(maxHealth: Int, expectedThreshold: Int)] = [
            (7, 2),
            (20, 4),
            (50, 10),
            (100, 20)
        ]
        for (maxHealth, expectedThreshold) in cases {
            XCTAssertEqual(
                PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: maxHealth),
                expectedThreshold,
                "maxHealth=\(maxHealth)"
            )
        }
    }

    func testZeroStatsProduceBaselineBonuses() {
        let stats = PrimaryStats()
        XCTAssertEqual(stats.statBonusForDamage(keyword: .physical), 0)
        XCTAssertEqual(stats.dodgeChance, 0.05, accuracy: 0.0001)
        XCTAssertEqual(stats.toughnessMitigationPct, 0.0, accuracy: 0.0001)
    }

    func testNegativeStatInputsTruncateTowardZeroForDamageBonus() {
        let stats = PrimaryStats(strength: -4, agility: -4, intellect: -4, wisdom: -4)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .physical), 0)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .bleed), 0)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .burn), 0)
        XCTAssertEqual(stats.statBonusForDamage(keyword: .poison), 0)
    }
}
