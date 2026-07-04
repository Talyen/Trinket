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

    func testBaseBattleAwardTargetsEarlyBattlesPerLevel() {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 1)
        XCTAssertEqual(award, 67)
        XCTAssertEqual(
            Double(CombatantProgression.requiredXP(forLevel: 1)) / Double(award),
            1.5,
            accuracy: 0.05
        )
    }

    func testBaseBattleAwardTargetsMidBattlesPerLevel() {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 25)
        XCTAssertEqual(
            Double(CombatantProgression.requiredXP(forLevel: 25)) / Double(award),
            2.5,
            accuracy: 0.05
        )
    }

    func testBaseBattleAwardTargetsLateBattlesPerLevel() {
        let award = ExperienceScaling.baseBattleAward(forPlayerLevel: 45)
        XCTAssertEqual(
            Double(CombatantProgression.requiredXP(forLevel: 45)) / Double(award),
            3.5,
            accuracy: 0.05
        )
    }

    func testBattleAwardAppliesLevelDeltaMultiplier() {
        XCTAssertEqual(ExperienceScaling.battleAward(playerLevel: 20, enemyLevel: 5), 0)
        XCTAssertGreaterThan(ExperienceScaling.battleAward(playerLevel: 5, enemyLevel: 5), 0)
    }
}
