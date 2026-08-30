import Testing
import TrinketCore

struct PrimaryStatsRulesTests {
    @Test func primaryStatsTotalCalculatesSum() throws {
        let stats = PrimaryStats(strength: 10, agility: 8, toughness: 12, intellect: 14, wisdom: 6)
        try #expect(stats.total == 50)
        try #expect(PrimaryStats().total == 0)
    }

    @Test func diminishingReturnsPercentCalculatesCorrectly() throws {
        try #expect(PrimaryStats.diminishingReturnsPercent(for: 0) == 0.0)
        try #expect(PrimaryStats.diminishingReturnsPercent(for: -10) == 0.0)
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

    @Test func contestedDodgeSubtractsAttackerAgility() throws {
        let defender = PrimaryStats(agility: 80)
        try #expect(defender.contestedDodgeChance(againstAttackerAgility: 80) == 0.0)
        try #expect(abs(defender.contestedDodgeChance(againstAttackerAgility: 0) - 0.50) < 0.0001)
        try #expect(abs(defender.contestedDodgeChance(againstAttackerAgility: 20) - 0.30) < 0.0001)
        try #expect(PrimaryStats(agility: 20).contestedDodgeChance(againstAttackerAgility: 80) == 0.0)
    }

    @Test func contestedEnemyDodgeCompressesHighDodgeWithFalloff() throws {
        let falloff = PrimaryStats.enemyDodgeFalloffConstant
        try #expect(falloff == 9.0)

        let defender = PrimaryStats(agility: 80)
        try #expect(abs(
            defender.contestedEnemyDodgeChance(againstAttackerAgility: 0) - 0.5 / (1 + falloff * 0.5)
        ) < 0.0001)
        try #expect(abs(
            defender.contestedEnemyDodgeChance(againstAttackerAgility: 20) - 0.3 / (1 + falloff * 0.3)
        ) < 0.0001)
        let low = PrimaryStats(agility: 17)
        let base = 17.0 / 97.0 - 12.0 / 92.0
        try #expect(abs(
            low.contestedEnemyDodgeChance(againstAttackerAgility: 12) - base / (1 + falloff * base)
        ) < 0.0001)
        try #expect(PrimaryStats(agility: 20).contestedEnemyDodgeChance(againstAttackerAgility: 80) == 0.0)
    }

    @Test func toughnessMitigationMatchesFormula() throws {
        try #expect(PrimaryStats(toughness: 0).toughnessMitigationPercent == 0.0)
        try #expect(abs(PrimaryStats(toughness: 20).toughnessMitigationPercent - 0.20) < 0.0001)
        try #expect(abs(PrimaryStats(toughness: 80).toughnessMitigationPercent - 0.50) < 0.0001)
        try #expect(abs(PrimaryStats(toughness: 120).toughnessMitigationPercent - 0.60) < 0.0001)
    }

    @Test func controlMeterThresholdScalesWithAgilityAndRoundsBaseHealth() throws {
        try #expect(PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: 100) == 20)
        try #expect(PrimaryStats(agility: 20).controlMeterThreshold(baseMaxHealth: 101) == 24)

        let cases: [(maxHealth: Int, expectedThreshold: Int)] = [
            (7, 1),
            (20, 4),
            (50, 10),
            (100, 20),
        ]
        for (maxHealth, expectedThreshold) in cases {
            try #expect(
                PrimaryStats(agility: 0).controlMeterThreshold(baseMaxHealth: maxHealth) == expectedThreshold,
                "maxHealth=\(maxHealth)"
            )
        }
    }

    @Test func contestedCriticalSubtractsDefenderToughness() throws {
        let attacker = PrimaryStats(agility: 80, intellect: 80, wisdom: 80)
        try #expect(attacker.contestedCriticalChance(for: .physical, againstDefenderToughness: 80) == 0.0)
        try #expect(abs(
            attacker.contestedCriticalChance(for: .physical, againstDefenderToughness: 0) - 0.50
        ) < 0.0001)
        try #expect(abs(
            attacker.contestedCriticalChance(for: .burn, againstDefenderToughness: 20) - 0.30
        ) < 0.0001)
        try #expect(abs(
            attacker.contestedCriticalChance(for: .holy, againstDefenderToughness: 20) - 0.30
        ) < 0.0001)
        try #expect(
            PrimaryStats(agility: 20).contestedCriticalChance(for: .physical, againstDefenderToughness: 80) == 0.0
        )
    }

    @Test func contestedCriticalIsZeroForNonCrittableKeywords() throws {
        let stats = PrimaryStats(agility: 100, intellect: 100, wisdom: 100)
        for keyword: Keyword in [.block, .dodge, .purge, .gold, .mana, .deathsDoor] {
            try #expect(
                stats.contestedCriticalChance(for: keyword, againstDefenderToughness: 0) == 0,
                "\(keyword.rawValue)"
            )
            try #expect(!keyword.allowsCriticalHits, "\(keyword.rawValue)")
        }
        try #expect(Keyword.health.allowsCriticalHits)
        try #expect(Keyword.leech.allowsCriticalHits)
        try #expect(Keyword.physical.allowsCriticalHits)
    }

    @Test func enemyArchetypeChanceCapsMatchDesign() throws {
        try #expect(GrowthArchetype.assassin.enemyDodgeChanceCap == 0.10)
        try #expect(GrowthArchetype.assassin.enemyCriticalChanceCap == 0.35)
        try #expect(GrowthArchetype.bruiser.enemyDodgeChanceCap == 0.08)
        try #expect(GrowthArchetype.bruiser.enemyCriticalChanceCap == 0.30)
        try #expect(GrowthArchetype.mage.enemyDodgeChanceCap == 0.05)
        try #expect(GrowthArchetype.mage.enemyCriticalChanceCap == 0.30)
        try #expect(GrowthArchetype.tank.enemyDodgeChanceCap == 0.05)
        try #expect(GrowthArchetype.tank.enemyCriticalChanceCap == 0.20)
        try #expect(GrowthArchetype.support.enemyDodgeChanceCap == 0.05)
        try #expect(GrowthArchetype.support.enemyCriticalChanceCap == 0.20)
    }

    @Test func negativeStatInputsReturnZeroForDamageBonus() throws {
        let stats = PrimaryStats(strength: -4, agility: -4, intellect: -4, wisdom: -4)
        try #expect(stats.statDamageBonusPercent(keyword: .physical) == 0.0)
        try #expect(stats.statDamageBonusPercent(keyword: .bleed) == 0.0)
        try #expect(stats.statDamageBonusPercent(keyword: .burn) == 0.0)
        try #expect(stats.statDamageBonusPercent(keyword: .poison) == 0.0)
    }
}
