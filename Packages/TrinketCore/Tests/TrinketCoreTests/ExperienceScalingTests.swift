import Testing
import TrinketCore

struct ExperienceScalingTests {
    @Test func `adjusted award covers level boundaries`() {
        #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 10, enemyLevel: 10) == 50,
        )
        #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 8, enemyLevel: 12) == 50,
        )
        #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 20, enemyLevel: 10) == 0,
        )
        #expect(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 20, enemyLevel: 5) == 0,
        )
    }

    @Test func `underlevel gap scales smoothly`() {
        let halfway = ExperienceScaling.adjustedAward(baseExperience: 100, playerLevel: 15, enemyLevel: 10)
        #expect(halfway > 0)
        #expect(halfway < 100)

        let nearEqual = ExperienceScaling.adjustedAward(baseExperience: 100, playerLevel: 11, enemyLevel: 10)
        #expect(nearEqual > halfway)
    }

    @Test func `base battle award targets early mid and late progression`() {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 1)
        #expect(award == 7)
        #expect(abs((
            Double(CombatantProgression.requiredXP(forLevel: 1)) / Double(award)
        ) - 1.5) < 0.1)
        for (level, battlesPerLevel) in [(25, 2.5), (45, 3.5)] {
            let award = ExperienceScaling.baseBattleAward(forPlayerLevel: level)
            #expect(abs((
                Double(CombatantProgression.requiredXP(forLevel: level)) / Double(award)
            ) - battlesPerLevel) < 0.05)
        }
    }

    @Test func `battle award applies level delta and catch up multiplier`() {
        #expect(ExperienceScaling.battleAward(playerLevel: 20, enemyLevel: 5) == 0)
        #expect(ExperienceScaling.battleAward(playerLevel: 5, enemyLevel: 5) == 25)

        #expect(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 20, enemyLevel: 5, highestLevel: 25) == 0,
        )

        #expect(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 5, enemyLevel: 5, highestLevel: 10)
                == 59,
        )
    }

    @Test func `equal battle award matches equal level catch up award`() {
        #expect(ExperienceScaling.equalBattleAward(playerLevel: 12, highestLevel: 18) == 201)
    }

    @Test func `capped award clips at three times required XP`() {
        let progression = CombatantProgression.at(level: 1)
        let ceiling = progression.requiredXP * ExperienceScaling.maxGrantLevelsEquivalent
        #expect(ceiling == 30)
        #expect(ExperienceScaling.cappedAward(5, for: progression) == 5)
        #expect(ExperienceScaling.cappedAward(30, for: progression) == 30)
        #expect(ExperienceScaling.cappedAward(1000, for: progression) == 30)
        #expect(ExperienceScaling.cappedAward(0, for: progression) == 0)
        #expect(ExperienceScaling.cappedAward(-5, for: progression) == 0)
    }

    @Test func `catch up multiplier covers baseline growth and caps`() {
        #expect(abs(ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 10) - 1.0) < 0.001)
        #expect(abs(ExperienceScaling.catchUpMultiplier(for: 20, highestLevel: 15) - 1.0) < 0.001)
        let gap1 = ExperienceScaling.catchUpMultiplier(for: 9, highestLevel: 10)
        let gap5 = ExperienceScaling.catchUpMultiplier(for: 5, highestLevel: 10)
        let gap10 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 11)
        #expect(gap1 > 1.0)
        #expect(gap5 > gap1)
        #expect(gap10 > gap5)
        let largeGap = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 100)
        #expect(largeGap <= 2.5)
        #expect(largeGap > 2.4)
        let customGap5 = ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 15, maxMultiplier: 2.0)
        #expect(customGap5 < 2.0)
        #expect(customGap5 > 1.5)

        let gap50 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 51, maxMultiplier: 3.0)
        #expect(gap50 < 3.0)
        #expect(gap50 > 2.9)
    }
}
