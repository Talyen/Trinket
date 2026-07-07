import TrinketCore
import XCTest

final class CombatantProgressionTests: XCTestCase {
    func testRequiredXPFollowsQuadraticCurve() {
        XCTAssertEqual(CombatantProgression.requiredXP(forLevel: 1), 100)
        XCTAssertEqual(CombatantProgression.requiredXP(forLevel: 2), 155)
        XCTAssertEqual(CombatantProgression.requiredXP(forLevel: 3), 220)
        XCTAssertEqual(CombatantProgression.requiredXP(forLevel: 6), 475)
    }

    func testAddingExperienceLevelsUpWhenThresholdReached() {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(10)
        XCTAssertEqual(leveled.level, 2)
        XCTAssertEqual(leveled.currentXP, 5)
        XCTAssertEqual(leveled.requiredXP, 155)
    }

    func testAddingExperienceCanLevelMultipleTimes() {
        let progression = CombatantProgression(level: 1, currentXP: 95, requiredXP: 100)
        let leveled = progression.addingExperience(200)
        XCTAssertEqual(leveled.level, 3)
        XCTAssertEqual(leveled.currentXP, 40)
        XCTAssertEqual(leveled.requiredXP, 220)
    }

    func testAddingNonPositiveExperienceIsNoOp() {
        let progression = CombatantProgression(level: 2, currentXP: 40, requiredXP: 155)
        XCTAssertEqual(progression.addingExperience(0), progression)
        XCTAssertEqual(progression.addingExperience(-10), progression)
    }

    func testProgressFractionClampsAndHandlesZeroRequired() {
        let empty = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        let half = CombatantProgression(level: 1, currentXP: 50, requiredXP: 100)
        let full = CombatantProgression(level: 1, currentXP: 100, requiredXP: 100)
        let overCap = CombatantProgression(level: 1, currentXP: 150, requiredXP: 100)
        let zeroRequired = CombatantProgression(level: 1, currentXP: 10, requiredXP: 0)

        XCTAssertEqual(empty.progressFraction, 0, accuracy: 0.001)
        XCTAssertEqual(half.progressFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(full.progressFraction, 1, accuracy: 0.001)
        XCTAssertEqual(overCap.progressFraction, 1, accuracy: 0.001)
        XCTAssertEqual(zeroRequired.progressFraction, 0, accuracy: 0.001)
    }

    func testUnlocksRespectsAbilityTierLevels() {
        let early = CombatantProgression(level: 1, currentXP: 0, requiredXP: 100)
        XCTAssertTrue(early.unlocks(.basic))
        XCTAssertTrue(early.unlocks(.skill))
        XCTAssertFalse(early.unlocks(.ultimate))

        let late = CombatantProgression(level: 6, currentXP: 0, requiredXP: 475)
        XCTAssertTrue(late.unlocks(.ultimate))
    }

    func testInitialProgressionUsesLevelOneRequiredXP() {
        XCTAssertEqual(CombatantProgression.initial.level, 1)
        XCTAssertEqual(CombatantProgression.initial.currentXP, 0)
        XCTAssertEqual(CombatantProgression.initial.requiredXP, 100)
    }

    func testRequiredXPForLevelZeroMatchesLevelOne() {
        XCTAssertEqual(CombatantProgression.requiredXP(forLevel: 0), 100)
        XCTAssertEqual(CombatantProgression.requiredXP(forLevel: 1), 100)
    }
}
