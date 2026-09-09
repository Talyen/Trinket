import Testing
import TrinketCore

struct CombatantProgressionTests {
    @Test(arguments: [(1, 10), (2, 15), (3, 22), (6, 47)])
    private func `required XP follows quadratic curve`(level: Int, expectedXP: Int) {
        #expect(CombatantProgression.requiredXP(forLevel: level) == expectedXP)
    }

    @Test func `required XP defaults to the level one curve`() {
        #expect(CombatantProgression.requiredXP(forLevel: 0) == 10)
        #expect(CombatantProgression.initial.requiredXP == 10)
    }

    @Test func `adding experience handles single and multiple level ups`() {
        let progression = CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
        let leveled = progression.addingExperience(2)
        #expect(leveled.level == 2)
        #expect(leveled.currentXP == 1)
        #expect(leveled.requiredXP == 15)
        let leveledMultiple = progression.addingExperience(20)
        #expect(leveledMultiple.level == 3)
        #expect(leveledMultiple.currentXP == 4)
        #expect(leveledMultiple.requiredXP == 22)
    }

    @Test(arguments: [40, 60, 100, 250, 1000])
    func `progression and catch up continue at high levels`(level: Int) {
        let progression = CombatantProgression.at(level: level)
        let advanced = progression.addingExperience(progression.requiredXP)
        #expect(advanced.level == level + 1)
        #expect(advanced.requiredXP > progression.requiredXP)
        let ordinary = ExperienceScaling.battleAward(playerLevel: level, enemyLevel: level)
        let catchUp = ExperienceScaling.battleAwardWithCatchUp(
            playerLevel: level, enemyLevel: level, highestLevel: level + 20,
        )
        #expect(ordinary > 0)
        #expect(catchUp > ordinary)
    }

    @Test func `adding non positive experience is no op`() {
        let progression = CombatantProgression(level: 2, currentXP: 4, requiredXP: 15)
        #expect(progression.addingExperience(0) == progression)
        #expect(progression.addingExperience(-1) == progression)
    }

    @Test func `progress fraction clamps and handles zero required`() {
        let empty = CombatantProgression(level: 1, currentXP: 0, requiredXP: 10)
        let half = CombatantProgression(level: 1, currentXP: 5, requiredXP: 10)
        let full = CombatantProgression(level: 1, currentXP: 10, requiredXP: 10)
        let overCap = CombatantProgression(level: 1, currentXP: 15, requiredXP: 10)
        let zeroRequired = CombatantProgression(level: 1, currentXP: 1, requiredXP: 0)

        #expect(abs((empty.progressFraction) - 0) < 0.001)
        #expect(abs((half.progressFraction) - 0.5) < 0.001)
        #expect(abs((full.progressFraction) - 1) < 0.001)
        #expect(abs((overCap.progressFraction) - 1) < 0.001)
        #expect(abs((zeroRequired.progressFraction) - 0) < 0.001)
    }

    @Test func `at level builds empty progress toward next level`() {
        let mid = CombatantProgression.at(level: 20)
        #expect(mid.level == 20)
        #expect(mid.currentXP == 0)
        #expect(mid.requiredXP == CombatantProgression.requiredXP(forLevel: 20))

        let clamped = CombatantProgression.at(level: 0)
        #expect(clamped == .initial)
    }
}
