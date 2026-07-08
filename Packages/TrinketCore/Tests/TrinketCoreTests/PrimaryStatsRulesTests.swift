import TrinketCore
import Testing

@Suite
struct PrimaryStatsRulesTests {
    @Test func statBonusForDamageUsesCorrectStat() {
        let stats = PrimaryStats(strength: 10, agility: 15, intellect: 20, wisdom: 25)
        #expect(stats.statBonusForDamage(keyword: .physical) == 2)
        #expect(stats.statBonusForDamage(keyword: .stun) == 2)
        #expect(stats.statBonusForDamage(keyword: .bleed) == 3)
        #expect(stats.statBonusForDamage(keyword: .burn) == 4)
        #expect(stats.statBonusForDamage(keyword: .freeze) == 4)
        #expect(stats.statBonusForDamage(keyword: .poison) == 5)
        #expect(stats.statBonusForDamage(keyword: .holy) == 5)
        #expect(stats.statBonusForDamage(keyword: .nature) == 5)
        #expect(stats.statBonusForDamage(keyword: .armor) == 0)
        #expect(stats.statBonusForDamage(keyword: .block) == 0)
    }

    @Test func dodgeChanceCapsAtSeventyFivePercent() {
        #expect(abs((PrimaryStats(agility: 0).dodgeChance) - (0.05)) < 0.0001)
        #expect(abs((PrimaryStats(agility: 10).dodgeChance) - (0.10)) < 0.0001)
        #expect(abs((PrimaryStats(agility: 100).dodgeChance) - (0.55)) < 0.0001)
        #expect(abs((PrimaryStats(agility: 1000).dodgeChance) - (0.75)) < 0.0001)
    }

    @Test func toughnessMitigationPctMatchesFormula() {
        #expect(abs((PrimaryStats(toughness: 0).toughnessMitigationPct) - (0.0)) < 0.0001)
        #expect(abs((PrimaryStats(toughness: 50).toughnessMitigationPct) - (0.5)) < 0.0001)
        #expect(abs((PrimaryStats(toughness: 100).toughnessMitigationPct) - (100.0 / 150.0)) < 0.0001)
    }

    @Test func controlMeterThresholdScalesWithAgility() {
        #expect(PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: 100) == 20)
        #expect(PrimaryStats(agility: 20).controlMeterThreshold(baseMaxHealth: 101) == 25)
    }

    @Test func criticalChanceUsesBaseAndStatScaling() {
        #expect(abs((PrimaryStats().criticalChance(for: .physical)) - (0.05)) < 0.0001)
        #expect(abs((PrimaryStats(agility: 20).criticalChance(for: .physical)) - (0.10)) < 0.0001)
        #expect(abs((PrimaryStats(intellect: 20).criticalChance(for: .burn)) - (0.10)) < 0.0001)
        #expect(abs((PrimaryStats(wisdom: 20).criticalChance(for: .holy)) - (0.10)) < 0.0001)
        #expect(abs((PrimaryStats(agility: 1000).criticalChance(for: .physical)) - (0.75)) < 0.0001)
    }

    @Test func controlMeterThresholdUsesCeilOfTwentyPercentMaxHealth() {
        let cases: [(maxHealth: Int, expectedThreshold: Int)] = [
            (7, 2),
            (20, 4),
            (50, 10),
            (100, 20)
        ]
        for (maxHealth, expectedThreshold) in cases {
            #expect(
                PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: maxHealth) == expectedThreshold,
                "maxHealth=\(maxHealth)"
            )
        }
    }

    @Test func zeroStatsProduceBaselineBonuses() {
        let stats = PrimaryStats()
        #expect(stats.statBonusForDamage(keyword: .physical) == 0)
        #expect(abs((stats.dodgeChance) - (0.05)) < 0.0001)
        #expect(abs((stats.toughnessMitigationPct) - (0.0)) < 0.0001)
    }

    @Test func negativeStatInputsTruncateTowardZeroForDamageBonus() {
        let stats = PrimaryStats(strength: -4, agility: -4, intellect: -4, wisdom: -4)
        #expect(stats.statBonusForDamage(keyword: .physical) == 0)
        #expect(stats.statBonusForDamage(keyword: .bleed) == 0)
        #expect(stats.statBonusForDamage(keyword: .burn) == 0)
        #expect(stats.statBonusForDamage(keyword: .poison) == 0)
    }
}
