import TrinketFeatureSupport
import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testCardInspectionPlayAutoBattleHandDragSafetyAndRetreatRestoresPlay() {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        battle.assertActive()
        battle.selectFirstBoon()

        let cards = battle.handCards
        let inspectedCard = cards.firstMatch
        XCTAssertTrue(inspectedCard.waitForExistence(timeout: Self.defaultTimeout))
        let inspectCountBefore = cards.count
        inspectedCard.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        XCTAssertEqual(cards.count, inspectCountBefore, "Inspecting a card must not play it")
        dismissSheet()
        inspectedCard.tap()
        XCTAssertTrue(
            waitForCardCount(cards, droppingFrom: inspectCountBefore),
            "The first tap after dismissing ability details must play the card",
        )

        let dragCard = cards.firstMatch
        XCTAssertTrue(dragCard.waitForExistence(timeout: Self.defaultTimeout))
        let dragCountBefore = cards.count
        let origin = dragCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240)),
        )
        XCTAssertTrue(
            waitForCardCount(cards, droppingFrom: dragCountBefore),
            "A successful drag play must remove one card",
        )

        let autoCountBefore = cards.count
        battle.autoBattleToggle.tap()
        XCTAssertTrue(
            waitForCardCountBelow(cards, autoCountBefore),
            "Auto Battle must reduce the hand",
        )
        battle.autoBattleToggle.tap()

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Knight")]
        assertExists(hero)

        battle.hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        let detailHeader = combatantDetail.header(for: "Knight")
        XCTAssertFalse(
            detailHeader.waitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details",
        )

        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertLoaded(for: "Knight")
        dismissSheet()

        assertButtonExists(AccessibilityID.Battle.actionsMenu)
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()
        assertButtonExists(AccessibilityID.Battle.retreatConfirm)
        battle.retreatConfirmAction.tap()

        XCTAssertTrue(
            app.tabBars.buttons[AccessibilityID.Tab.play].waitForExistence(timeout: Self.defaultTimeout),
            "Tab bar should return after retreat",
        )
        play.assertCampaignLoaded(number: 1)
    }

    private func waitForCardCount(_ cards: XCUIElementQuery, droppingFrom initial: Int) -> Bool {
        let predicate = NSPredicate(format: "count == %d", initial - 1)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: cards)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }

    private func waitForCardCountBelow(_ cards: XCUIElementQuery, _ initial: Int) -> Bool {
        let predicate = NSPredicate(format: "count < %d", initial)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: cards)
        return XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    }
}
