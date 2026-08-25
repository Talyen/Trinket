import Testing
import TrinketCore

struct ExperienceScalingTests {
    @Test func adjustedAwardCoversLevelBoundaries() throws {
        try #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 10, enemyLevel: 10) == 50
        )
        try #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 8, enemyLevel: 12) == 50
        )
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

    @Test func baseBattleAwardTargetsEarlyMidAndLateProgression() throws {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 1)
        try #expect(award == 7)
        try #expect(abs((
            Double(CombatantProgression.requiredXP(forLevel: 1)) / Double(award)
        ) - 1.5) < 0.1)
        for (level, battlesPerLevel) in [(25, 2.5), (45, 3.5)] {
            let award = ExperienceScaling.baseBattleAward(forPlayerLevel: level)
            try #expect(abs((
                Double(CombatantProgression.requiredXP(forLevel: level)) / Double(award)
            ) - battlesPerLevel) < 0.05)
        }
    }

    @Test func battleAwardAppliesLevelDeltaAndCatchUpMultiplier() throws {
        try #expect(ExperienceScaling.battleAward(playerLevel: 20, enemyLevel: 5) == 0)
        try #expect(ExperienceScaling.battleAward(playerLevel: 5, enemyLevel: 5) == 25)

        try #expect(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 20, enemyLevel: 5, highestLevel: 25) == 0
        )

        // Pinned values, not re-derived: level-5 equal fight (25 base) × catch-up
        // toward highest 10 (≈2.377) rounds to 59.
        try #expect(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 5, enemyLevel: 5, highestLevel: 10)
                == 59
        )
    }

    @Test func equalBattleAwardMatchesEqualLevelCatchUpAward() throws {
        // Pinned equal-level award for player 12 catching up to highest 18.
        try #expect(ExperienceScaling.equalBattleAward(playerLevel: 12, highestLevel: 18) == 201)
    }

    @Test func cappedAwardClipsAtThreeTimesRequiredXP() throws {
        let progression = CombatantProgression.at(level: 1)
        let ceiling = progression.requiredXP * ExperienceScaling.maxGrantLevelsEquivalent
        try #expect(ceiling == 30)
        try #expect(ExperienceScaling.cappedAward(5, for: progression) == 5)
        try #expect(ExperienceScaling.cappedAward(30, for: progression) == 30)
        try #expect(ExperienceScaling.cappedAward(1000, for: progression) == 30)
        try #expect(ExperienceScaling.cappedAward(0, for: progression) == 0)
        try #expect(ExperienceScaling.cappedAward(-5, for: progression) == 0)
    }

    // MARK: - Catch-up multiplier

    @Test func catchUpMultiplierCoversBaselineGrowthAndCaps() throws {
        try #expect(abs(ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 10) - 1.0) < 0.001)
        try #expect(abs(ExperienceScaling.catchUpMultiplier(for: 20, highestLevel: 15) - 1.0) < 0.001)
        let gap1 = ExperienceScaling.catchUpMultiplier(for: 9, highestLevel: 10)
        let gap5 = ExperienceScaling.catchUpMultiplier(for: 5, highestLevel: 10)
        let gap10 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 11)
        try #expect(gap1 > 1.0)
        try #expect(gap5 > gap1)
        try #expect(gap10 > gap5)
        let largeGap = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 100)
        try #expect(largeGap <= 2.5)
        try #expect(largeGap > 2.4)
        let customGap5 = ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 15, maxMultiplier: 2.0)
        try #expect(customGap5 < 2.0)
        try #expect(customGap5 > 1.5)

        let gap50 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 51, maxMultiplier: 3.0)
        try #expect(gap50 < 3.0)
        try #expect(gap50 > 2.9)
    }
}
