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
        let segments = ExperienceBar.segments(from: pre, to: post)
        try #expect(segments.count == 1)
        try #expect(abs(segments[0].startFraction - pre.progressFraction) < 0.001)
        try #expect(abs(segments[0].endFraction - post.progressFraction) < 0.001)
        try #expect(segments[0].endXP == post.currentXP)
        try #expect(segments[0].levelsGained == 0)
        try #expect(segments[0].newLevel == post.level)
    }

    @Test func `single level-up fills then restarts the bar`() throws {
        let pre = CombatantProgression(level: 2, currentXP: 14, requiredXP: 15)
        let post = CombatantProgression(level: 3, currentXP: 1, requiredXP: 22)
        let segments = ExperienceBar.segments(from: pre, to: post)
        try #expect(segments.count == 2)
        try #expect(abs(segments[0].startFraction - pre.progressFraction) < 0.001)
        try #expect(abs(segments[0].endFraction - 1.0) < 0.001)
        try #expect(segments[0].levelsGained == 1)
        try #expect(segments[0].newLevel == 3)
        try #expect(segments[0].newRequiredXP == 22)
        try #expect(abs(segments[1].startFraction - 0.0) < 0.001)
        try #expect(abs(segments[1].endFraction - post.progressFraction) < 0.001)
        try #expect(segments[1].endXP == post.currentXP)
        try #expect(segments[1].levelsGained == 0)
        try #expect(segments[1].newLevel == 3)
        try #expect(segments[1].newRequiredXP == post.requiredXP)
    }

    @Test func `double level-up chains full intermediate bars`() throws {
        let pre = CombatantProgression(level: 1, currentXP: 9, requiredXP: 10)
        let post = pre.addingExperience(20)
        try #expect(post.level == 3)
        try #expect(post.currentXP == 4)
        try #expect(post.requiredXP == 22)
        let segments = ExperienceBar.segments(from: pre, to: post)
        try #expect(segments.count == 3)
        try #expect(abs(segments[0].startFraction - 0.9) < 0.001)
        try #expect(abs(segments[0].endFraction - 1.0) < 0.001)
        try #expect(segments[0].levelsGained == 1)
        try #expect(segments[0].newLevel == 2)
        try #expect(segments[0].newRequiredXP == 15)
        try #expect(abs(segments[1].startFraction - 0.0) < 0.001)
        try #expect(abs(segments[1].endFraction - 1.0) < 0.001)
        try #expect(segments[1].levelsGained == 1)
        try #expect(segments[1].newLevel == 3)
        try #expect(segments[1].newRequiredXP == 22)
        try #expect(abs(segments[2].startFraction - 0.0) < 0.001)
        try #expect(abs(segments[2].endFraction - 0.182) < 0.01)
        try #expect(segments[2].levelsGained == 0)
        try #expect(segments[2].newLevel == 3)
        try #expect(segments[2].endXP == 4)
    }

    @Test func `level chains match adding experience`() throws {
        let pre = CombatantProgression(level: 3, currentXP: 14, requiredXP: 22)
        let delta = 33
        let post = pre.addingExperience(delta)

        let segments = ExperienceBar.segments(from: pre, to: post)
        let totalLevelUps = segments.count(where: { $0.levelsGained > 0 })
        try #expect(totalLevelUps == post.level - pre.level)
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
