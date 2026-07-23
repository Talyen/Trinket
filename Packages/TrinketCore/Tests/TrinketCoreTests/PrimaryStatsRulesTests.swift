import Testing
import TrinketCore

struct PrimaryStatsRulesTests {
    @Test func diminishingReturnsPercentCalculatesCorrectly() throws {
        try #expect(PrimaryStats.diminishingReturnsPercent(for: 0) == 0.0)
        try #expect(abs(PrimaryStats.diminishingReturnsPercent(for: 20) - 0.20) < 0.0001)
        try #expect(abs(PrimaryStats.diminishingReturnsPercent(for: 80) - 0.50) < 0.0001)
        try #expect(abs(PrimaryStats.diminishingReturnsPercent(for: 120) - 0.60) < 0.0001)
    }

    @Test func statDamageBonusPercentUsesCorrectStatAndCurve() throws {
        let stats = PrimaryStats(strength: 20, agility: 80, intellect: 120, wisdom: 20)
        try #expect(abs(stats.statDamageBonusPercent(keyword: .physical) - 0.20) < 0.0001)
        try #expect(abs(stats.statDamageBonusPercent(keyword: .stun) - 0.20) < 0.0001)
        try #expect(abs(stats.statDamageBonusPercent(keyword: .bleed) - 0.50) < 0.0001)
        try #expect(abs(stats.statDamageBonusPercent(keyword: .burn) - 0.60) < 0.0001)
        try #expect(abs(stats.statDamageBonusPercent(keyword: .freeze) - 0.60) < 0.0001)
        try #expect(abs(stats.statDamageBonusPercent(keyword: .poison) - 0.20) < 0.0001)
        try #expect(abs(stats.statDamageBonusPercent(keyword: .holy) - 0.20) < 0.0001)
        try #expect(stats.statDamageBonusPercent(keyword: .block) == 0.0)
    }

    @Test func dodgeChanceCapsAtSeventyFivePercent() throws {
        try #expect(PrimaryStats(agility: 0).dodgeChance == 0.0)
        try #expect(abs((PrimaryStats(agility: 20).dodgeChance) - 0.20) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 80).dodgeChance) - 0.50) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 1000).dodgeChance) - 0.75) < 0.0001)
    }

    @Test func toughnessMitigationMatchesFormula() throws {
        try #expect(PrimaryStats(toughness: 0).toughnessMitigationPercent == 0.0)
        try #expect(abs(PrimaryStats(toughness: 20).toughnessMitigationPercent - 0.20) < 0.0001)
        try #expect(abs(PrimaryStats(toughness: 80).toughnessMitigationPercent - 0.50) < 0.0001)
        try #expect(abs(PrimaryStats(toughness: 120).toughnessMitigationPercent - 0.60) < 0.0001)
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

    @Test func criticalChanceUsesStatDiminishingReturnsScaling() throws {
        try #expect(PrimaryStats().criticalChance(for: .physical) == 0.0)
        try #expect(abs((PrimaryStats(agility: 20).criticalChance(for: .physical)) - 0.20) < 0.0001)
        try #expect(abs((PrimaryStats(intellect: 20).criticalChance(for: .burn)) - 0.20) < 0.0001)
        try #expect(abs((PrimaryStats(wisdom: 20).criticalChance(for: .holy)) - 0.20) < 0.0001)
        try #expect(abs((PrimaryStats(wisdom: 20).criticalChance(for: .health)) - 0.20) < 0.0001)
        try #expect(abs((PrimaryStats(wisdom: 20).criticalChance(for: .leech)) - 0.20) < 0.0001)
        try #expect(abs((PrimaryStats(agility: 1000).criticalChance(for: .physical)) - 0.75) < 0.0001)
    }

    @Test func criticalChanceIsZeroForNonCrittableKeywords() throws {
        let stats = PrimaryStats(agility: 100, intellect: 100, wisdom: 100)
        for keyword: Keyword in [.block, .dodge, .purge, .gold, .mana, .deathsDoor] {
            try #expect(stats.criticalChance(for: keyword) == 0, "\(keyword.rawValue)")
            try #expect(!keyword.allowsCriticalHits, "\(keyword.rawValue)")
        }
        try #expect(Keyword.health.allowsCriticalHits)
        try #expect(Keyword.leech.allowsCriticalHits)
        try #expect(Keyword.physical.allowsCriticalHits)
    }

    @Test func negativeStatInputsReturnZeroForDamageBonus() throws {
        let stats = PrimaryStats(strength: -4, agility: -4, intellect: -4, wisdom: -4)
        try #expect(stats.statDamageBonusPercent(keyword: .physical) == 0.0)
        try #expect(stats.statDamageBonusPercent(keyword: .bleed) == 0.0)
        try #expect(stats.statDamageBonusPercent(keyword: .burn) == 0.0)
        try #expect(stats.statDamageBonusPercent(keyword: .poison) == 0.0)
    }
}
