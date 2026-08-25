import Testing
import TrinketCore

struct CombatantProgressionTests {
    @Test(arguments: [(1, 10), (2, 15), (3, 22), (6, 47)])
    private func requiredXPFollowsQuadraticCurve(level: Int, expectedXP: Int) throws {
        try #expect(CombatantProgression.requiredXP(forLevel: level) == expectedXP)
    }

    @Test func requiredXPDefaultsToTheLevelOneCurve() throws {
        try #expect(CombatantProgression.requiredXP(forLevel: 0) == 10)
        try #expect(CombatantProgression.initial.requiredXP == 10)
    }

    @Test func addingExperienceHandlesSingleAndMultipleLevelUps() throws {
        let progression = CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
        let leveled = progression.addingExperience(2)
        try #expect(leveled.level == 2)
        try #expect(leveled.currentXP == 1)
        try #expect(leveled.requiredXP == 15)
        let leveledMultiple = progression.addingExperience(20)
        try #expect(leveledMultiple.level == 3)
        try #expect(leveledMultiple.currentXP == 4)
        try #expect(leveledMultiple.requiredXP == 22)
    }

    @Test func addingNonPositiveExperienceIsNoOp() throws {
        let progression = CombatantProgression(level: 2, currentXP: 4, requiredXP: 15)
        try #expect(progression.addingExperience(0) == progression)
        try #expect(progression.addingExperience(-1) == progression)
    }

    @Test func progressFractionClampsAndHandlesZeroRequired() throws {
        let empty = CombatantProgression(level: 1, currentXP: 0, requiredXP: 10)
        let half = CombatantProgression(level: 1, currentXP: 5, requiredXP: 10)
        let full = CombatantProgression(level: 1, currentXP: 10, requiredXP: 10)
        let overCap = CombatantProgression(level: 1, currentXP: 15, requiredXP: 10)
        let zeroRequired = CombatantProgression(level: 1, currentXP: 1, requiredXP: 0)

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
