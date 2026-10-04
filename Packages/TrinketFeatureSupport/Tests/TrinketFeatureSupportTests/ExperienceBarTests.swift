import Testing
import TrinketCore
@testable import TrinketFeatureSupport

struct ExperienceBarTests {
    @Test func `identical progression yields no segments`() throws {
        let pre = CombatantProgression(level: 2, currentXP: 3, requiredXP: 15)
        try #expect(ExperienceBar.segments(from: pre, to: pre).isEmpty)
    }

    @Test(arguments: [
        (
            pre: CombatantProgression(level: 2, currentXP: 3, requiredXP: 15),
            post: CombatantProgression(level: 2, currentXP: 6, requiredXP: 15),
        ),
        (
            pre: CombatantProgression(level: 3, currentXP: 10, requiredXP: 22),
            post: CombatantProgression(level: 1, currentXP: 2, requiredXP: 10),
        ),
        (
            pre: CombatantProgression(level: 2, currentXP: 8, requiredXP: 15),
            post: CombatantProgression(level: 2, currentXP: 3, requiredXP: 15),
        ),
    ])
    func `single segment spans the progression delta`(
        pre: CombatantProgression,
        post: CombatantProgression,
    ) throws {
        try #expect(ExperienceBar.segments(from: pre, to: post) == [ExperienceBar.Segment(
            startFraction: pre.progressFraction,
            endFraction: post.progressFraction,
            endXP: post.currentXP,
            levelsGained: 0,
            newLevel: post.level,
            newRequiredXP: post.requiredXP,
        )])
    }

    @Test func `double level-up chains full intermediate bars`() throws {
        let pre = CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
        let post = pre.addingExperience(20)
        try #expect(ExperienceBar.segments(from: pre, to: post) == [
            ExperienceBar.Segment(
                startFraction: 0.9, endFraction: 1.0, endXP: 10,
                levelsGained: 1, newLevel: 2, newRequiredXP: 15,
            ),
            ExperienceBar.Segment(
                startFraction: 0.0, endFraction: 1.0, endXP: 15,
                levelsGained: 1, newLevel: 3, newRequiredXP: 22,
            ),
            ExperienceBar.Segment(
                startFraction: 0.0, endFraction: 4.0 / 22.0, endXP: 4,
                levelsGained: 0, newLevel: 3, newRequiredXP: 22,
            ),
        ])
    }

    @Test(arguments: [1, 2, 3, 20])
    func `level chains preserve fill time and cap the reward wait`(segmentCount: Int) {
        let duration = ExperienceBar.segmentDuration(forSegmentCount: segmentCount)
        #expect(abs(duration * Double(segmentCount) - ExperienceBar.animationBudget) < 0.001)
        let levelCount = segmentCount - 1
        let totalDuration = ExperienceBar.initialDelay + duration * Double(segmentCount)
            + ExperienceBar.levelUpDuration(forLevelCount: levelCount) * Double(levelCount)
            + ExperienceBar.settleDuration
        #expect(totalDuration <= 1.20 + 0.001)
        #expect(ExperienceBar.segmentDuration(forSegmentCount: 0) == 0)
        #expect(ExperienceBar.levelUpDuration(forLevelCount: 0) == 0)
    }
}
