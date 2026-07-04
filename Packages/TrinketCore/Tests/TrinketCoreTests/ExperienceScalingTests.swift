import XCTest
import TrinketCore

final class ExperienceScalingTests: XCTestCase {
    func testEqualLevelAwardsFullExperience() {
        XCTAssertEqual(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 10, enemyLevel: 10),
            50
        )
    }

    func testHigherLevelEnemyAwardsFullExperience() {
        XCTAssertEqual(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 8, enemyLevel: 12),
            50
        )
    }

    func testEnemyTenOrMoreLevelsBelowAwardsNothing() {
        XCTAssertEqual(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 20, enemyLevel: 10),
            0
        )
        XCTAssertEqual(
            ExperienceScaling.adjustedAward(baseExperience: 50, playerLevel: 20, enemyLevel: 5),
            0
        )
    }

    func testUnderlevelGapScalesSmoothly() {
        let halfway = ExperienceScaling.adjustedAward(baseExperience: 100, playerLevel: 15, enemyLevel: 10)
        XCTAssertGreaterThan(halfway, 0)
        XCTAssertLessThan(halfway, 100)

        let nearEqual = ExperienceScaling.adjustedAward(baseExperience: 100, playerLevel: 11, enemyLevel: 10)
        XCTAssertGreaterThan(nearEqual, halfway)
    }
}
