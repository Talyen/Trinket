import Testing
import TrinketCore

struct CombatantProgressionTests {
    @Test(arguments: [(1, 10), (2, 15), (3, 22), (6, 47), (3100000001, 4805000015500000010), (3100000002, 4805000018600000015)])
    private func `required XP follows quadratic curve`(level: Int, expectedXP: Int) {
        #expect(CombatantProgression.requiredXP(forLevel: level) == expectedXP)
    }

    @Test func `required XP defaults to the level one curve`() {
        #expect(CombatantProgression.requiredXP(forLevel: 0) == 10)
        #expect(CombatantProgression.requiredXP(forLevel: -100) == 10)
        #expect(CombatantProgression.requiredXP(forLevel: Int.min) == 10)
        #expect(CombatantProgression.initial.requiredXP == 10)
        #expect(CombatantProgression.at(level: 0) == .initial)
    }

    @Test func `adding extreme experience saturates without trapping`() {
        // Bounded: exercises the Int.max-level guard directly instead of
        // leveling ~3.8M times from level 1.
        let nearCap = CombatantProgression(level: Int.max - 1, currentXP: 0, requiredXP: 10)
        let capped = nearCap.addingExperience(Int.max)
        #expect(capped.level == Int.max)
        #expect(capped.currentXP >= 0)

        // Saturated requirement: one level-up consumes the whole grant.
        let saturated = CombatantProgression(level: 1000, currentXP: 0, requiredXP: Int.max)
        let advanced = saturated.addingExperience(Int.max)
        #expect(advanced.level == 1001)
        #expect(advanced.currentXP == 0)

        #expect(CombatantProgression.requiredXP(forLevel: Int.max) == Int.max)
    }

    @Test func `adding experience at max level retains accumulated experience`() {
        let maxLevelProgression = CombatantProgression(level: Int.max, currentXP: 50, requiredXP: 100)
        let result = maxLevelProgression.addingExperience(200)
        #expect(result.level == Int.max)
        #expect(result.currentXP == 250)
        #expect(result.requiredXP == 100)
    }

    @Test func `adding experience preserves exact multi level remainder`() {
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

    @Test(arguments: [40, 1000])
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

    @Test(arguments: [(0, 10, 0.0), (5, 10, 0.5), (15, 10, 1.0), (-1, 10, 0.0), (1, 0, 0.0)])
    func `progress fraction stays within the experience bar`(current: Int, required: Int, expected: Double) {
        #expect(CombatantProgression(level: 1, currentXP: current, requiredXP: required).progressFraction == expected)
    }

    @Test func `total earned experience preserves the curve and saturates at extreme levels`() {
        for level in [1, 2, 3, 4, 5, 6, 19, 20, 39, 40, 999, 1000] {
            let expected = (1 ..< level).reduce(7) { $0 + CombatantProgression.requiredXP(forLevel: $1) }
            let progression = CombatantProgression(level: level, currentXP: 7, requiredXP: 0)
            #expect(progression.totalEarnedExperience == expected)
        }
        #expect(CombatantProgression.at(level: Int.max).totalEarnedExperience == Int.max)
        #expect(CombatantProgression(level: 2, currentXP: Int.max, requiredXP: 15).totalEarnedExperience == Int.max)
    }
}
