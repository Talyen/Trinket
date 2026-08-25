import Testing
import TrinketCore
@testable import TrinketDesignSystem

struct ExperienceBarTests {
    @Test(arguments: [
        (
            pre: CombatantProgression(level: 2, currentXP: 3, requiredXP: 15),
            post: CombatantProgression(level: 2, currentXP: 3, requiredXP: 15),
            expectedCount: 0
        ),
        (
            pre: CombatantProgression(level: 2, currentXP: 3, requiredXP: 15),
            post: CombatantProgression(level: 2, currentXP: 6, requiredXP: 15),
            expectedCount: 1
        ),
        (
            pre: CombatantProgression(level: 2, currentXP: 14, requiredXP: 15),
            post: CombatantProgression(level: 3, currentXP: 1, requiredXP: 22),
            expectedCount: 2
        ),
        (
            pre: CombatantProgression(level: 1, currentXP: 9, requiredXP: 10),
            post: CombatantProgression(level: 1, currentXP: 9, requiredXP: 10).addingExperience(20),
            expectedCount: 3
        ),
    ])
    func experienceSegmentsCoverProgressionCases(
        pre: CombatantProgression,
        post: CombatantProgression,
        expectedCount: Int
    ) throws {
        let segments = ExperienceBar.segments(from: pre, to: post)
        try #expect(segments.count == expectedCount)

        if expectedCount == 0 {
            return
        }

        if expectedCount == 1 {
            try #expect(abs(segments[0].startFraction - pre.progressFraction) < 0.001)
            try #expect(abs(segments[0].endFraction - post.progressFraction) < 0.001)
            try #expect(segments[0].endXP == post.currentXP)
            try #expect(segments[0].levelsGained == 0)
            try #expect(segments[0].newLevel == post.level)
            return
        }

        if expectedCount == 2 {
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
            return
        }

        try #expect(post.level == 3)
        try #expect(post.currentXP == 4)
        try #expect(post.requiredXP == 22)
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

    @Test func levelChainsMatchAddingExperience() throws {
        let pre = CombatantProgression(level: 3, currentXP: 14, requiredXP: 22)
        let delta = 33
        let post = pre.addingExperience(delta)

        let segments = ExperienceBar.segments(from: pre, to: post)
        let totalLevelUps = segments.count(where: { $0.levelsGained > 0 })
        try #expect(totalLevelUps == post.level - pre.level)
    }
}
