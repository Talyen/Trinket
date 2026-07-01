import XCTest
@testable import Trinket

final class ExperienceBarSegmentsTests: XCTestCase {
    func testNoChangeReturnsEmptySegments() {
        let progression = CombatantProgression(level: 2, currentXP: 35, requiredXP: 120)
        let segments = ExperienceBar.segments(from: progression, to: progression)
        XCTAssertTrue(segments.isEmpty)
    }

    func testNoLevelUpProducesSingleSegment() {
        let pre = CombatantProgression(level: 2, currentXP: 35, requiredXP: 120)
        let post = CombatantProgression(level: 2, currentXP: 59, requiredXP: 120)

        let segments = ExperienceBar.segments(from: pre, to: post)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].startFraction, pre.progressFraction, accuracy: 0.001)
        XCTAssertEqual(segments[0].endFraction, post.progressFraction, accuracy: 0.001)
        XCTAssertEqual(segments[0].endXP, post.currentXP)
        XCTAssertEqual(segments[0].levelsGained, 0)
        XCTAssertEqual(segments[0].newLevel, post.level)
    }

    func testSingleLevelUpProducesTwoSegments() {
        let pre = CombatantProgression(level: 2, currentXP: 100, requiredXP: 120)
        let post = CombatantProgression(level: 3, currentXP: 5, requiredXP: 170)

        let segments = ExperienceBar.segments(from: pre, to: post)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].startFraction, pre.progressFraction, accuracy: 0.001)
        XCTAssertEqual(segments[0].endFraction, 1.0, accuracy: 0.001)
        XCTAssertEqual(segments[0].levelsGained, 1)
        XCTAssertEqual(segments[0].newLevel, 3)
        XCTAssertEqual(segments[0].newRequiredXP, 170)
        XCTAssertEqual(segments[1].startFraction, 0.0, accuracy: 0.001)
        XCTAssertEqual(segments[1].endFraction, post.progressFraction, accuracy: 0.001)
        XCTAssertEqual(segments[1].endXP, post.currentXP)
        XCTAssertEqual(segments[1].levelsGained, 0)
        XCTAssertEqual(segments[1].newLevel, 3)
        XCTAssertEqual(segments[1].newRequiredXP, post.requiredXP)
    }

    func testMultiLevelUpProducesThreeSegments() {
        let pre = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let post = pre.addingExperience(200)

        XCTAssertEqual(post.level, 3)
        XCTAssertEqual(post.currentXP, 45)
        XCTAssertEqual(post.requiredXP, 200)

        let segments = ExperienceBar.segments(from: pre, to: post)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].startFraction, 0.95, accuracy: 0.001)
        XCTAssertEqual(segments[0].endFraction, 1.0, accuracy: 0.001)
        XCTAssertEqual(segments[0].levelsGained, 1)
        XCTAssertEqual(segments[0].newLevel, 2)
        XCTAssertEqual(segments[0].newRequiredXP, 150)

        XCTAssertEqual(segments[1].startFraction, 0.0, accuracy: 0.001)
        XCTAssertEqual(segments[1].endFraction, 1.0, accuracy: 0.001)
        XCTAssertEqual(segments[1].levelsGained, 1)
        XCTAssertEqual(segments[1].newLevel, 3)
        XCTAssertEqual(segments[1].newRequiredXP, 200)

        XCTAssertEqual(segments[2].startFraction, 0.0, accuracy: 0.001)
        XCTAssertEqual(segments[2].endFraction, 0.225, accuracy: 0.001)
        XCTAssertEqual(segments[2].levelsGained, 0)
        XCTAssertEqual(segments[2].newLevel, 3)
        XCTAssertEqual(segments[2].endXP, 45)
    }

    func testLevelChainsMatchAddingExperience() {
        let pre = CombatantProgression(level: 3, currentXP: 140, requiredXP: 200)
        let delta = 330
        let post = pre.addingExperience(delta)

        let segments = ExperienceBar.segments(from: pre, to: post)
        let totalLevelUps = segments.filter { $0.levelsGained > 0 }.count
        XCTAssertEqual(totalLevelUps, post.level - pre.level)
    }
}
