import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    /// Mid-battle interactions: enter via Play map and assert turn-based chrome stays visible.
    func testMidBattleCombatantDetailAndHandChrome() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.screen("battle"))

        // If Stage 1-1 already resolved, mid-battle chrome is gone — defer to the victory test.
        if battle.waitForMidBattleOrVictory() {
            return
        }

        // Knight is the card we open; Wolf may already be downed / off-layout mid-fight.
        assertExists(AccessibilityID.CombatantDetail.battleCard(name: "Knight"))

        // Turn-based chrome: hand should be present mid-battle.
        battle.assertActive()
        assertExists(AccessibilityID.Battle.hand)

        XCTAssertFalse(app.tabBars.firstMatch.exists, "Tab bar should be hidden during battle")
        assertButtonExists(AccessibilityID.Battle.actionsMenu)

        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.combatLog)
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.combatLogAction.tap()
        assertExists(AccessibilityID.Battle.combatLog)
        app.buttons["Close Combat Log"].tap()

        if battle.victory.waitForExistence(timeout: 1) {
            return
        }

        battle.assertPresented()
        battle.assertActive()
        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertSeededHeroHeaderSummary(for: "Knight")
        assertCombatantDetailSections()
        dismissSheet()
    }

    /// Victory remains focused on Battle; Combat Log is available from Battle Actions.
    func testBattleVictorySummaryAndPostVictoryMenu() {
        launchApp(arguments: TestLaunchArg.allForBattleVictory())

        assertExists(battle.victory, timeout: Self.defaultTimeout)

        assertExists(AccessibilityID.Battle.experience)
        assertExists(AccessibilityID.Battle.rewards)
        assertButtonExists(AccessibilityID.Battle.continueButton)

        XCTAssertFalse(app.tabBars.firstMatch.exists, "Tab bar should be hidden until victory is completed")
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.combatLog)
        XCTAssertFalse(battle.retreatAction.exists, "Retreat should be unavailable after victory")
        battle.combatLogAction.tap()
        assertExists(AccessibilityID.Battle.combatLog)
    }

    func testRetreatRestoresPlayNavigation() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.screen("battle"))

        battle.assertActive()
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: Self.defaultTimeout),
            "Tab bar should return after retreat"
        )
        play.assertLoaded()
    }
}
