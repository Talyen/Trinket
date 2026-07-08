import TrinketCore
import Testing

@Suite
struct CombatantProgressionTests {
    @Test func requiredXPFollowsQuadraticCurve() {
        #expect(CombatantProgression.requiredXP(forLevel: 1) == 100)
        #expect(CombatantProgression.requiredXP(forLevel: 2) == 155)
        #expect(CombatantProgression.requiredXP(forLevel: 3) == 220)
        #expect(CombatantProgression.requiredXP(forLevel: 6) == 475)
    }

    @Test func addingExperienceLevelsUpWhenThresholdReached() {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(10)
        #expect(leveled.level == 2)
        #expect(leveled.currentXP == 5)
        #expect(leveled.requiredXP == 155)
    }

    @Test func addingExperienceCanLevelMultipleTimes() {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(200)
        #expect(leveled.level == 3)
        #expect(leveled.currentXP == 40)
        #expect(leveled.requiredXP == 220)
    }

    @Test func addingNonPositiveExperienceIsNoOp() {
        let progression = CombatantProgression(level: 2, currentXP: 40, requiredXP: 155)
        #expect(progression.addingExperience(0) == progression)
        #expect(progression.addingExperience(-10) == progression)
    }

    @Test func progressFractionClampsAndHandlesZeroRequired() {
        let empty = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let half = CombatantProgression(level: 1, currentXP: 50, requiredXP: 100)
        let full = CombatantProgression(level: 1, currentXP: 100, requiredXP: 100)
        let overCap = CombatantProgression(level: 1, currentXP: 150, requiredXP: 100)
        let zeroRequired = CombatantProgression(level: 1, currentXP: 10, requiredXP: 0)

        #expect(abs((empty.progressFraction) - (0)) < 0.001)
        #expect(abs((half.progressFraction) - (0.5)) < 0.001)
        #expect(abs((full.progressFraction) - (1)) < 0.001)
        #expect(abs((overCap.progressFraction) - (1)) < 0.001)
        #expect(abs((zeroRequired.progressFraction) - (0)) < 0.001)
    }

    @Test func unlocksRespectsAbilityTierLevels() {
        let early = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        #expect(early.unlocks(.basic))
        #expect(early.unlocks(.skill))
        #expect(!(early.unlocks(.ultimate)))

        let late = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)
        #expect(late.unlocks(.ultimate))
    }

    @Test func initialProgressionUsesLevelOneRequiredXP() {
        #expect(CombatantProgression.initial.level == 1)
        #expect(CombatantProgression.initial.currentXP == 0)
        #expect(CombatantProgression.initial.requiredXP == 100)
    }

    @Test func requiredXPForLevelZeroMatchesLevelOne() {
        #expect(CombatantProgression.requiredXP(forLevel: 0) == 100)
        #expect(CombatantProgression.requiredXP(forLevel: 1) == 100)
    }
}
