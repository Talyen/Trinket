import Testing
import TrinketCore

struct CombatantProgressionTests {
    @Test func requiredXPFollowsQuadraticCurve() throws {
        try #expect(CombatantProgression.requiredXP(forLevel: 1) == 100)
        try #expect(CombatantProgression.requiredXP(forLevel: 2) == 155)
        try #expect(CombatantProgression.requiredXP(forLevel: 3) == 220)
        try #expect(CombatantProgression.requiredXP(forLevel: 6) == 475)
    }

    @Test func addingExperienceLevelsUpWhenThresholdReached() throws {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(10)
        try #expect(leveled.level == 2)
        try #expect(leveled.currentXP == 5)
        try #expect(leveled.requiredXP == 155)
    }

    @Test func addingExperienceCanLevelMultipleTimes() throws {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(200)
        try #expect(leveled.level == 3)
        try #expect(leveled.currentXP == 40)
        try #expect(leveled.requiredXP == 220)
    }

    @Test func addingNonPositiveExperienceIsNoOp() throws {
        let progression = CombatantProgression(level: 2, currentXP: 40, requiredXP: 155)
        try #expect(progression.addingExperience(0) == progression)
        try #expect(progression.addingExperience(-10) == progression)
    }

    @Test func progressFractionClampsAndHandlesZeroRequired() throws {
        let empty = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let half = CombatantProgression(level: 1, currentXP: 50, requiredXP: 100)
        let full = CombatantProgression(level: 1, currentXP: 100, requiredXP: 100)
        let overCap = CombatantProgression(level: 1, currentXP: 150, requiredXP: 100)
        let zeroRequired = CombatantProgression(level: 1, currentXP: 10, requiredXP: 0)

        try #expect(abs((empty.progressFraction) - 0) < 0.001)
        try #expect(abs((half.progressFraction) - 0.5) < 0.001)
        try #expect(abs((full.progressFraction) - 1) < 0.001)
        try #expect(abs((overCap.progressFraction) - 1) < 0.001)
        try #expect(abs((zeroRequired.progressFraction) - 0) < 0.001)
    }

    @Test func unlocksRespectsAbilityTierLevels() throws {
        let early = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        try #expect(early.unlocks(.basic))
        try #expect(early.unlocks(.skill))
        try #expect(!(early.unlocks(.ultimate)))

        let late = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)
        try #expect(late.unlocks(.ultimate))
    }

    @Test func initialProgressionUsesLevelOneRequiredXP() throws {
        try #expect(CombatantProgression.initial.level == 1)
        try #expect(CombatantProgression.initial.currentXP == 0)
        try #expect(CombatantProgression.initial.requiredXP == 100)
    }

    @Test func requiredXPForLevelZeroMatchesLevelOne() throws {
        try #expect(CombatantProgression.requiredXP(forLevel: 0) == 100)
        try #expect(CombatantProgression.requiredXP(forLevel: 1) == 100)
    }

    @Test func atLevelBuildsEmptyProgressTowardNextLevel() throws {
        let mid = CombatantProgression.at(level: 20)
        try #expect(mid.level == 20)
        try #expect(mid.currentXP == 0)
        try #expect(mid.requiredXP == CombatantProgression.requiredXP(forLevel: 20))

        let clamped = CombatantProgression.at(level: 0)
        try #expect(clamped == .initial)
    }
}
