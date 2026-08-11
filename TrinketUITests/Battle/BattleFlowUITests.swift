import TrinketFeatureSupport
import XCTest

/// Mid-battle interactions share one entry via `allForMidBattle` (60s ticks),
/// so the opening hand stays put and never races into live-tick resolution.
/// Victory chrome is covered by its own deep-link test; hand-drag safety and
/// retreat live here as the single UI owner.
final class BattleFlowUITests: TrinketUITestCase {
    func testCardPlayRemovesOneCard() {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        let cards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Battle Hand Card ")
        )

        // Tap-to-play is a supported input path; one card must leave the hand.
        let tapCard = cards.firstMatch
        XCTAssertTrue(tapCard.waitForExistence(timeout: Self.defaultTimeout))
        let tapCountBefore = cards.count
        tapCard.tap()
        XCTAssertTrue(
            waitForCardCount(cards, droppingFrom: tapCountBefore),
            "A successful tap must remove one card"
        )

        // Drag-to-play is the primary gesture; one card must leave the hand.
        let dragCard = cards.firstMatch
        XCTAssertTrue(dragCard.waitForExistence(timeout: Self.defaultTimeout))
        let dragCountBefore = cards.count
        let origin = dragCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240))
        )
        XCTAssertTrue(
            waitForCardCount(cards, droppingFrom: dragCountBefore),
            "A successful drag play must remove one card"
        )
    }

    /// Hand drag onto a combatant must not open details; tap still works after.
    /// Retreat then restores Play navigation. Single owner for these invariants.
    func testHandDragSafetyAndRetreatRestoresPlayNavigation() {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

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

        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertLoaded(for: "Knight")
        dismissSheet()

        assertButtonExists(AccessibilityID.Battle.actionsMenu)
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: Self.defaultTimeout),
            "Tab bar should return after retreat"
        )
        play.assertCampaignLoaded(number: 1)
    }

    /// Victory remains focused on rewards; continue and reward item detail are reachable.
    func testBattleVictorySummaryAndPostVictoryCTA() {
        launchApp(arguments: TestLaunchArg.allForBattleVictory())

        assertExists(battle.victory, timeout: Self.defaultTimeout)
        assertExists(AccessibilityID.Battle.rewards)
        assertExists(AccessibilityID.Battle.experience)
        assertButtonExists(AccessibilityID.Battle.continueButton)

        let rewardItemID = "chapter-1-stage-1-loot"
        assertButtonExists(AccessibilityID.Battle.rewardItem(rewardItemID))
        tapButton(AccessibilityID.Battle.rewardItem(rewardItemID))
        // Sheet + hero header art can take longer under exhaustive suite load than smoke.
        assertExists(AccessibilityID.LoadoutPicker.itemDetail(rewardItemID), timeout: 12)
        dismissSheet()
        assertButtonExists(AccessibilityID.Battle.continueButton)
    }

    private func waitForCardCount(_ cards: XCUIElementQuery, droppingFrom initial: Int) -> Bool {
        let predicate = NSPredicate(format: "count == %d", initial - 1)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: cards)
        return XCTWaiter().wait(for: [expectation], timeout: Self.defaultTimeout) == .completed
    }
}
