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

        let handCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Battle Hand Card ")
        ).firstMatch
        XCTAssertTrue(
            handCard.waitForExistence(timeout: Self.defaultTimeout),
            "Expected a battle hand card to drag"
        )

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Ranger")]
        XCTAssertTrue(hero.waitForExistence(timeout: Self.defaultTimeout))

        handCard.press(forDuration: 0.2, thenDragTo: hero)

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
