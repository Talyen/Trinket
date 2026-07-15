import Testing
import TrinketCore

struct PrimaryStatsRulesTests {
    @Test func statBonusForDamageUsesCorrectStat() throws {
        let stats = PrimaryStats(strength: 10, agility: 15, intellect: 20, wisdom: 25)
        try #expect(stats.statBonusForDamage(keyword: .physical) == 2)
        try #expect(stats.statBonusForDamage(keyword: .stun) == 2)
        try #expect(stats.statBonusForDamage(keyword: .bleed) == 3)
        try #expect(stats.statBonusForDamage(keyword: .burn) == 4)
        try #expect(stats.statBonusForDamage(keyword: .freeze) == 4)
        try #expect(stats.statBonusForDamage(keyword: .poison) == 5)
        try #expect(stats.statBonusForDamage(keyword: .holy) == 5)
        try #expect(stats.statBonusForDamage(keyword: .nature) == 5)
        try #expect(stats.statBonusForDamage(keyword: .armor) == 0)
        try #expect(stats.statBonusForDamage(keyword: .block) == 0)
    }

    @Test func dodgeChanceCapsAtSeventyFivePercent() throws {
        try #expect(abs((PrimaryStats(agility: 0).dodgeChance) - 0.05) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 10).dodgeChance) - 0.10) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 100).dodgeChance) - 0.55) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 1000).dodgeChance) - 0.75) < 0.0001)
    }

    @Test func armorEffectivenessBonusMatchesFormula() throws {
        try #expect(PrimaryStats(toughness: 0).armorEffectivenessBonus == 0)
        try #expect(PrimaryStats(toughness: 5).armorEffectivenessBonus == 1)
        try #expect(PrimaryStats(toughness: 50).armorEffectivenessBonus == 10)
        try #expect(PrimaryStats(toughness: 100).armorEffectivenessBonus == 20)
    }

    @Test func controlMeterThresholdScalesWithAgilityAndCeilsBaseHealth() throws {
        try #expect(PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: 100) == 20)
        try #expect(PrimaryStats(agility: 20).controlMeterThreshold(baseMaxHealth: 101) == 25)

        let cases: [(maxHealth: Int, expectedThreshold: Int)] = [
            (7, 2),
            (20, 4),
            (50, 10),
            (100, 20)
        ]
        for (maxHealth, expectedThreshold) in cases {
            try #expect(
                PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: maxHealth) == expectedThreshold,
                "maxHealth=\(maxHealth)"
            )
        }
    }

    @Test func criticalChanceUsesBaseAndStatScaling() throws {
        try #expect(abs((PrimaryStats().criticalChance(for: .physical)) - 0.05) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 20).criticalChance(for: .physical)) - 0.10) < 0.0001)
        try #expect(abs((PrimaryStats(intellect: 20).criticalChance(for: .burn)) - 0.10) < 0.0001)
        try #expect(abs((PrimaryStats(wisdom: 20).criticalChance(for: .holy)) - 0.10) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 1000).criticalChance(for: .physical)) - 0.75) < 0.0001)
    }

    @Test func negativeStatInputsTruncateTowardZeroForDamageBonus() throws {
        let stats = PrimaryStats(strength: -4, agility: -4, intellect: -4, wisdom: -4)
        try #expect(stats.statBonusForDamage(keyword: .physical) == 0)
        try #expect(stats.statBonusForDamage(keyword: .bleed) == 0)
        try #expect(stats.statBonusForDamage(keyword: .burn) == 0)
        try #expect(stats.statBonusForDamage(keyword: .poison) == 0)
    }
}
