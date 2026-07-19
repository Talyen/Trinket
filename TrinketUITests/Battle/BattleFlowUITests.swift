import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testSuccessfulCardReleaseRemovesOneCardWithoutOpeningDetail() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; covered by the victory test")
        }

        let cards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Battle Hand Card ")
        )
        let countBefore = cards.count
        let card = cards.firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.defaultTimeout))
        let origin = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240))
        )

        let deadline = Date().addingTimeInterval(3)
        while cards.count == countBefore, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(cards.count, countBefore - 1, "A successful play must remove one card")
        XCTAssertFalse(
            combatantDetail.header(for: "Knight").exists,
            "Playing a card must not open combatant detail"
        )
    }

    /// Hand drag onto a combatant must not open details; tap still works after.
    /// Single owner for this safety invariant (not in smoke).
    func testHandDragReleaseOnCombatantDoesNotOpenDetail() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; mid-battle chrome covered by victory test")
        }

        battle.assertActive()
        assertExists(battle.hand)

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Knight")]
        assertExists(hero)

        battle.hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        let detailHeader = combatantDetail.header(for: "Knight")
        XCTAssertFalse(
            detailHeader.waitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details"
        )

        if battle.victory.waitForExistence(timeout: 1) {
            throw XCTSkip("Battle resolved during hand-drag assertions; covered by victory test")
        }

        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertLoaded(for: "Knight")
    }

    /// Victory remains focused on Battle; continue and reward item detail are reachable.
    func testBattleVictorySummaryAndPostVictoryMenu() {
        launchApp(arguments: TestLaunchArg.allForBattleVictory())

        assertExists(battle.victory, timeout: Self.defaultTimeout)
        assertExists(AccessibilityID.Battle.rewards)
        assertExists(AccessibilityID.Battle.experience)
        assertButtonExists(AccessibilityID.Battle.continueButton)

        let rewardItemID = "chapter-1-stage-1-loot"
        assertButtonExists(AccessibilityID.Battle.rewardItem(rewardItemID))
        tapButton(AccessibilityID.Battle.rewardItem(rewardItemID))
        // Sheet + hero header art can take longer under exhaustive suite load than smoke.
        // Journey loot for chapter-1-stage-1 is seed-stable Leather Armor (BattleLootTests).
        XCTAssertTrue(
            app.navigationBars["Leather Armor"].waitForExistence(timeout: 12),
            "Reward item detail sheet did not present"
        )
        assertExists(AccessibilityID.LoadoutPicker.itemDetail(rewardItemID), timeout: 8)
        dismissSheet()
        assertButtonExists(AccessibilityID.Battle.continueButton)

        XCTAssertFalse(app.tabBars.firstMatch.exists, "Tab bar should be hidden until victory is completed")
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.combatLog)
        XCTAssertFalse(battle.retreatAction.exists, "Retreat should be unavailable after victory")
    }

    func testRetreatRestoresPlayNavigation() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

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
