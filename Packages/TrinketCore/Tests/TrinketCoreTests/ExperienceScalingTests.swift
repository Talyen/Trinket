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

    // MARK: - Catch-up multiplier

    func testCatchUpMultiplierIsOneAtNoGap() {
        XCTAssertEqual(ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 10), 1.0, accuracy: 0.001)
        XCTAssertEqual(ExperienceScaling.catchUpMultiplier(for: 20, highestLevel: 15), 1.0, accuracy: 0.001)
    }

    func testCatchUpMultiplierIncreasesWithGap() {
        let gap1 = ExperienceScaling.catchUpMultiplier(for: 9, highestLevel: 10)
        let gap5 = ExperienceScaling.catchUpMultiplier(for: 5, highestLevel: 10)
        let gap10 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 11)
        XCTAssertGreaterThan(gap1, 1.0)
        XCTAssertGreaterThan(gap5, gap1)
        XCTAssertGreaterThan(gap10, gap5)
    }

    func testCatchUpMultiplierApproachesMax() {
        let largeGap = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 100)
        XCTAssertLessThanOrEqual(largeGap, 2.5)
        XCTAssertGreaterThan(largeGap, 2.4)
    }

    func testCatchUpMultiplierCustomMax() {
        let gap5 = ExperienceScaling.catchUpMultiplier(for: 10, highestLevel: 15, maxMultiplier: 2.0)
        XCTAssertLessThan(gap5, 2.0)
        XCTAssertGreaterThan(gap5, 1.5)

        let gap50 = ExperienceScaling.catchUpMultiplier(for: 1, highestLevel: 51, maxMultiplier: 3.0)
        XCTAssertLessThan(gap50, 3.0)
        XCTAssertGreaterThan(gap50, 2.9)
    }

    func testBattleAwardWithCatchUpReturnsZeroWhenBaseAwardIsZero() {
        XCTAssertEqual(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 20, enemyLevel: 5, highestLevel: 25),
            0
        )
    }

    func testBattleAwardWithCatchUpAppliesCatchUpMultiplier() {
        let baseAward = ExperienceScaling.battleAward(playerLevel: 5, enemyLevel: 5)
        let catchUp = ExperienceScaling.catchUpMultiplier(for: 5, highestLevel: 10)
        let expected = max(1, Int((Double(baseAward) * catchUp).rounded()))

        XCTAssertEqual(
            ExperienceScaling.battleAwardWithCatchUp(playerLevel: 5, enemyLevel: 5, highestLevel: 10),
            expected
        )
    }
}
