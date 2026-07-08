import Testing
import TrinketCore

@Suite
struct ExperienceScalingTests {
    @Test func equalLevelAwardsFullExperience() throws {
        try #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 10, enemyLevel: 10) == 50
        )
    }

    @Test func higherLevelEnemyAwardsFullExperience() throws {
        try #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 8, enemyLevel: 12) == 50
        )
    }

    @Test func enemyTenOrMoreLevelsBelowAwardsNothing() throws {
        try #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 20, enemyLevel: 10) == 0
        )
        try #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 20, enemyLevel: 5) == 0
        )
    }

    @Test func underlevelGapScalesSmoothly() throws {
        let halfway = ExperienceScaling.adjustedAward(baseExperience: 100, playerLevel: 15, enemyLevel: 10)
        try #expect(halfway > 0)
        try #expect(halfway < 100)

        let nearEqual = ExperienceScaling.adjustedAward(baseExperience: 100, playerLevel: 11, enemyLevel: 10)
        try #expect(nearEqual > halfway)
    }

    @Test func baseBattleAwardTargetsEarlyBattlesPerLevel() throws {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 1)
        try #expect(award == 67)
        try #expect(abs((
            Double(CombatantProgression.requiredXP(forLevel: 1)) / Double(award)) - (1.5)) < 0.05
        )
    }

    @Test func baseBattleAwardTargetsMidBattlesPerLevel() throws {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 25)
        try #expect(abs((
            Double(CombatantProgression.requiredXP(forLevel: 25)) / Double(award)) - (2.5)) < 0.05
        )
    }

    @Test func baseBattleAwardTargetsLateBattlesPerLevel() throws {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 45)
        try #expect(abs((
            Double(CombatantProgression.requiredXP(forLevel: 45)) / Double(award)) - (3.5)) < 0.05
        )
    }

    @Test func battleAwardAppliesLevelDeltaMultiplier() throws {
        try #expect(ExperienceScaling.battleAward(playerLevel: 20, enemyLevel: 5) == 0)
        try #expect(ExperienceScaling.battleAward(playerLevel: 5, enemyLevel: 5) > 0)
    }

    // MARK: - Catch-up multiplier

    @Test func catchUpMultiplierIsOneAtNoGap() throws {
        try #expect(abs(ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 10) - 1.0) < 0.001)
        try #expect(abs(ExperienceScaling.catchUpMultiplier(for: 20, highestLevel: 15) - 1.0) < 0.001)
    }

    @Test func catchUpMultiplierIncreasesWithGap() throws {
        let gap1 = ExperienceScaling.catchUpMultiplier(for: 9, highestLevel: 10)
        let gap5 = ExperienceScaling.catchUpMultiplier(for: 5, highestLevel: 10)
        let gap10 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 11)
        try #expect(gap1 > 1.0)
        try #expect(gap5 > gap1)
        try #expect(gap10 > gap5)
    }

    @Test func catchUpMultiplierApproachesMax() throws {
        let largeGap = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 100)
        try #expect(largeGap <= 2.5)
        try #expect(largeGap > 2.4)
    }

    @Test func catchUpMultiplierCustomMax() throws {
        let gap5 = ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 15, maxMultiplier: 2.0)
        try #expect(gap5 < 2.0)
        try #expect(gap5 > 1.5)

        let gap50 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 51, maxMultiplier: 3.0)
        try #expect(gap50 < 3.0)
        try #expect(gap50 > 2.9)
    }

    @Test func battleAwardWithCatchUpReturnsZeroWhenBaseAwardIsZero() throws {
        try #expect(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 20, enemyLevel: 5, highestLevel: 25) == 0
        )
    }

    @Test func battleAwardWithCatchUpAppliesCatchUpMultiplier() throws {
        let baseAward = ExperienceScaling.battleAward(playerLevel: 5, enemyLevel: 5)
        let catchUp = ExperienceScaling.catchUpMultiplier(for: 5, highestLevel: 10)
        let expected = max(1, Int((Double(baseAward) * catchUp).rounded()))

        try #expect(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 5, enemyLevel: 5, highestLevel: 10) == expected
        )
    }
}
