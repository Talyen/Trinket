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

    func testDotResistanceMultiplierMatchesFormula() {
        XCTAssertEqual(PrimaryStats(toughness: 0).dotResistanceMultiplier, 1.0, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 50).dotResistanceMultiplier, 0.75, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 100).dotResistanceMultiplier, 0.5, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 200).dotResistanceMultiplier, 0.25, accuracy: 0.0001)
        XCTAssertEqual(PrimaryStats(toughness: 1000).dotResistanceMultiplier, 0.25, accuracy: 0.0001)
    }

    func testPreventionThresholdScalesWithAgility() {
        XCTAssertEqual(PrimaryStats(agility: 0).preventionThreshold(baseMaxHealth: 100), 20)
        XCTAssertEqual(PrimaryStats(agility: 20).preventionThreshold(baseMaxHealth: 101), 25)
    }
}
