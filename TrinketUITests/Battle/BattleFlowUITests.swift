import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    /// Mid-battle interactions: enter via Play map and assert turn-based chrome stays visible.
    func testMidBattleCombatantDetailAndHandChrome() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        // If Stage 1-1 already resolved, mid-battle chrome is gone — skip rather than false-green.
        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; mid-battle chrome covered by victory test")
        }

        // Ranger is the card we open; Wolf may already be downed / off-layout mid-fight.
        assertExists(AccessibilityID.CombatantDetail.battleCard(name: "Ranger"))

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
        XCTAssertFalse(app.buttons["Close Combat Log"].exists)
        dismissSheet()

        if battle.victory.waitForExistence(timeout: 1) {
            throw XCTSkip("Battle resolved during mid-battle assertions; covered by victory test")
        }

        battle.assertPresented()
        battle.assertActive()
        battle.openCombatantCard(named: "Ranger")
        assertCombatantDetailSections()
        dismissSheet()
    }

    /// Hand drag onto a combatant must not open details; tap still works after.
    /// Kept out of smoke: mid-battle interactions enter via Play map, not `-launch-screen battle`.
    func testHandDragReleaseOnCombatantDoesNotOpenDetail() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; mid-battle chrome covered by victory test")
        }

        battle.assertActive()
        assertExists(battle.hand)

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Ranger")]
        assertExists(hero)

        battle.hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        let detailHeader = combatantDetail.header(for: "Ranger")
        XCTAssertFalse(
            detailHeader.waitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details"
        )

        if battle.victory.waitForExistence(timeout: 1) {
            throw XCTSkip("Battle resolved during hand-drag assertions; covered by victory test")
        }

        battle.openCombatantCard(named: "Ranger")
        combatantDetail.assertLoaded(for: "Ranger")
    }

    /// Victory remains focused on Battle; Combat Log is available from Battle Actions.
    func testBattleVictorySummaryAndPostVictoryMenu() {
        launchApp(arguments: TestLaunchArg.allForBattleVictory())

        assertExists(battle.victory, timeout: Self.defaultTimeout)

        assertExists(AccessibilityID.Battle.experience)
        XCTAssertFalse(app.buttons["Victory Reward Chest"].exists)
        XCTAssertFalse(app.buttons["Open Rewards Button"].exists)

        assertExists(AccessibilityID.Battle.rewards)
        assertExists(AccessibilityID.Battle.experience)
        assertExists(AccessibilityID.Battle.rewardItem("chapter-1-stage-1-shortsword-basic"))
        XCTAssertEqual(
            app.buttons.matching(identifier: AccessibilityID.Battle.rewardItem("chapter-1-stage-1-shortsword-basic")).count,
            0
        )
        assertExists(app.staticTexts["BASIC"])
        assertExists(app.staticTexts["Shortsword"])
        assertButtonExists(AccessibilityID.Battle.continueButton)

        XCTAssertFalse(app.tabBars.firstMatch.exists, "Tab bar should be hidden until victory is completed")
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.combatLog)
        XCTAssertFalse(battle.retreatAction.exists, "Retreat should be unavailable after victory")
        battle.combatLogAction.tap()
        assertExists(AccessibilityID.Battle.combatLog)
    }

    func testRetreatRestoresPlayNavigation() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        // Stage 1-1 can resolve before retreat is reachable — skip rather than false-green.
        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; mid-battle chrome covered by victory test")
        }

        battle.assertActive()
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: Self.defaultTimeout),
            "Tab bar should return after retreat"
        )
        play.assertCampaignLoaded(number: 1)
    }
}
