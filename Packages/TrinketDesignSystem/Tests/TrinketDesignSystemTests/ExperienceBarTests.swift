import Testing
import TrinketCore
import TrinketDesignSystem

struct ExperienceBarTests {
    @Test func noChangeReturnsEmptySegments() throws {
        let progression = CombatantProgression(level: 2, currentXP: 35, requiredXP: 155)
        let segments = ExperienceBar.segments(from: progression, to: progression)
        try #expect(segments.isEmpty)
    }

    @Test func noLevelUpProducesSingleSegment() throws {
        let pre = CombatantProgression(level: 2, currentXP: 35, requiredXP: 155)
        let post = CombatantProgression(level: 2, currentXP: 59, requiredXP: 155)

        let segments = ExperienceBar.segments(from: pre, to: post)

        try #expect(segments.count == 1)
        try #expect(abs((segments[0].startFraction) - (pre.progressFraction)) < 0.001)
        try #expect(abs((segments[0].endFraction) - (post.progressFraction)) < 0.001)
        try #expect(segments[0].endXP == post.currentXP)
        try #expect(segments[0].levelsGained == 0)
        try #expect(segments[0].newLevel == post.level)
    }

    @Test func singleLevelUpProducesTwoSegments() throws {
        let pre = CombatantProgression(level: 2, currentXP: 140, requiredXP: 155)
        let post = CombatantProgression(level: 3, currentXP: 5, requiredXP: 220)

        let segments = ExperienceBar.segments(from: pre, to: post)

        try #expect(segments.count == 2)
        try #expect(abs((segments[0].startFraction) - (pre.progressFraction)) < 0.001)
        try #expect(abs((segments[0].endFraction) - 1.0) < 0.001)
        try #expect(segments[0].levelsGained == 1)
        try #expect(segments[0].newLevel == 3)
        try #expect(segments[0].newRequiredXP == 220)
        try #expect(abs((segments[1].startFraction) - 0.0) < 0.001)
        try #expect(abs((segments[1].endFraction) - (post.progressFraction)) < 0.001)
        try #expect(segments[1].endXP == post.currentXP)
        try #expect(segments[1].levelsGained == 0)
        try #expect(segments[1].newLevel == 3)
        try #expect(segments[1].newRequiredXP == post.requiredXP)
    }

    @Test func multiLevelUpProducesThreeSegments() throws {
        let pre = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let post = pre.addingExperience(200)

        try #expect(post.level == 3)
        try #expect(post.currentXP == 40)
        try #expect(post.requiredXP == 220)

        let segments = ExperienceBar.segments(from: pre, to: post)

        try #expect(segments.count == 3)
        try #expect(abs((segments[0].startFraction) - 0.95) < 0.001)
        try #expect(abs((segments[0].endFraction) - 1.0) < 0.001)
        try #expect(segments[0].levelsGained == 1)
        try #expect(segments[0].newLevel == 2)
        try #expect(segments[0].newRequiredXP == 155)

        try #expect(abs((segments[1].startFraction) - 0.0) < 0.001)
        try #expect(abs((segments[1].endFraction) - 1.0) < 0.001)
        try #expect(segments[1].levelsGained == 1)
        try #expect(segments[1].newLevel == 3)
        try #expect(segments[1].newRequiredXP == 220)

        try #expect(abs((segments[2].startFraction) - 0.0) < 0.001)
        try #expect(abs((segments[2].endFraction) - 0.182) < 0.01)
        try #expect(segments[2].levelsGained == 0)
        try #expect(segments[2].newLevel == 3)
        try #expect(segments[2].endXP == 40)
    }

    @Test func levelChainsMatchAddingExperience() throws {
        let pre = CombatantProgression(level: 3, currentXP: 140, requiredXP: 220)
        let delta = 330
        let post = pre.addingExperience(delta)

        let segments = ExperienceBar.segments(from: pre, to: post)
        let totalLevelUps = segments.filter { $0.levelsGained > 0 }.count
        try #expect(totalLevelUps == post.level - pre.level)
    }
}
