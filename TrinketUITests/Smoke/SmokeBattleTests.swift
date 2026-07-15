import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    func testBattleLaunchScreenStartsStageOneOne() {
        battle.assertActive()
    }

    func testCombatantTapOpensDetail() {
        battle.assertActive()
        if battle.waitForMidBattleOrVictory() {
            return
        }

        battle.openCombatantCard(named: "Ranger")
        combatantDetail.assertLoaded(for: "Ranger")
    }

    func testHandDragReleaseOnCombatantDoesNotOpenDetail() {
        battle.assertActive()
        if battle.waitForMidBattleOrVictory() {
            return
        }

        let hand = app.images[AccessibilityID.Battle.hand].firstMatch
        XCTAssertTrue(hand.waitForExistence(timeout: Self.defaultTimeout), "Expected battle hand chrome")

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Ranger")]
        XCTAssertTrue(hero.waitForExistence(timeout: Self.defaultTimeout))

        hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        let detailHeader = combatantDetail.header(for: "Ranger")
        XCTAssertFalse(
            detailHeader.waitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details"
        )

        // Single tap still opens details after the drag suppress window.
        battle.openCombatantCard(named: "Ranger")
        combatantDetail.assertLoaded(for: "Ranger")
    }
}
