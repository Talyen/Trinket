import TrinketFeatureSupport
import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testHandCardInspectTapAndDragPlay() {
        launchMidBattleAndStart()

        let cards = battle.handCards
        let inspectedCard = cards.firstMatch
        XCTAssertTrue(inspectedCard.trinketWaitForExistence(timeout: Self.defaultTimeout))
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
        XCTAssertTrue(dragCard.trinketWaitForExistence(timeout: Self.defaultTimeout))
        let dragCountBefore = cards.count
        let origin = dragCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        assertCancelledDrag(from: origin, cards: cards)
        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240)),
        )
        XCTAssertTrue(
            waitForCardCount(cards, droppingFrom: dragCountBefore),
            "A successful drag play must remove one card",
        )

        let autoCountBefore = cards.count
        tapWhenReady(battle.autoBattleToggle)
        XCTAssertTrue(
            waitForCardCountBelow(cards, autoCountBefore),
            "Auto Battle must reduce the hand",
        )
        tapWhenReady(battle.autoBattleToggle)
    }

    func testHandDragSafetyAndCombatantDetail() {
        launchMidBattleAndStart()

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Knight")]
        assertExists(hero)

        battle.hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        let detailHeader = combatantDetail.header(for: "Knight")
        XCTAssertFalse(
            detailHeader.trinketWaitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details",
        )

        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertLoaded(for: "Knight")
        dismissSheet()
    }

    private func launchMidBattleAndStart() {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        battle.assertActive()
    }

    private func assertCancelledDrag(from origin: XCUICoordinate, cards: XCUIElementQuery) {
        let countBefore = cards.count
        // Cross the shared movement boundary, then hold beyond native long-press recognition.
        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 11, dy: 0)),
            withVelocity: XCUIGestureVelocity(rawValue: 40),
            thenHoldForDuration: 0.7,
        )
        XCTAssertEqual(cards.count, countBefore, "A drag below the play threshold must leave the hand unchanged")
        assertDoesNotExist(AccessibilityID.Battle.abilityDetail)

        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -60)),
            withVelocity: .fast,
            thenHoldForDuration: 0,
        )
        XCTAssertEqual(cards.count, countBefore, "A flick released inside the play boundary must cancel")
        assertDoesNotExist(AccessibilityID.Battle.abilityDetail)
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
