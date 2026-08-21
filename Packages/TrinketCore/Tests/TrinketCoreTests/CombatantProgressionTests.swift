import Testing
import TrinketCore

struct CombatantProgressionTests {
    @Test(arguments: [(1, 100), (2, 155), (3, 220), (6, 475)])
    private func requiredXPFollowsQuadraticCurve(level: Int, expectedXP: Int) throws {
        try #expect(CombatantProgression.requiredXP(forLevel: level) == expectedXP)
    }

    @Test func requiredXPDefaultsToTheLevelOneCurve() throws {
        try #expect(CombatantProgression.requiredXP(forLevel: 0) == 100)
        try #expect(CombatantProgression.initial.requiredXP == 100)
    }

    @Test func addingExperienceHandlesSingleAndMultipleLevelUps() throws {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(10)
        try #expect(leveled.level == 2)
        try #expect(leveled.currentXP == 5)
        try #expect(leveled.requiredXP == 155)
        let leveledMultiple = progression.addingExperience(200)
        try #expect(leveledMultiple.level == 3)
        try #expect(leveledMultiple.currentXP == 40)
        try #expect(leveledMultiple.requiredXP == 220)
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

    @Test func atLevelBuildsEmptyProgressTowardNextLevel() throws {
        let mid = CombatantProgression.at(level: 20)
        try #expect(mid.level == 20)
        try #expect(mid.currentXP == 0)
        try #expect(mid.requiredXP == CombatantProgression.requiredXP(forLevel: 20))

        let clamped = CombatantProgression.at(level: 0)
        try #expect(clamped == .initial)
    }
}
