import TrinketFeatureSupport
import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testHandInspectionDismissalAndDragPreserveCardPlay() {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()

        let inspectedCard = battle.frontmostHandCard
        XCTAssertTrue(inspectedCard.trinketWaitForExistence(timeout: Self.defaultTimeout))
        let inspectedCardID = inspectedCard.identifier
        inspectedCard.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        XCTAssertTrue(button(inspectedCardID).exists, "Inspecting a card must not play it")
        attachSuccessScreenshot(named: "hand-ability-inspection")
        dismissSheet(AccessibilityID.Battle.abilityDetail)

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Ranger")]
        assertExists(hero)
        battle.hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let detailHeader = combatantDetail.header(for: "Ranger")
        XCTAssertFalse(
            detailHeader.trinketWaitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details",
        )
        battle.openCombatantCard(named: "Ranger")
        combatantDetail.assertLoaded(for: "Ranger")
        attachSuccessScreenshot(named: "hand-combatant-detail")
        dismissSheet(AccessibilityID.CombatantDetail.header(name: "Ranger"))

        let tapCard = battle.frontmostHandCard
        let tapCardID = tapCard.identifier
        tapWhenReady(tapCard)
        // Draw effects can replace a played card without reducing the hand size.
        waitUntil("The first tap after dismissing details must play the card") { !self.button(tapCardID).exists }
        let dragCard = battle.frontmostHandCard
        assertExists(dragCard)
        let dragCardID = dragCard.identifier
        let origin = dragCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // Cross the shared movement boundary, then hold beyond native long-press recognition.
        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 11, dy: 0)),
            withVelocity: XCUIGestureVelocity(rawValue: 40),
            thenHoldForDuration: 0.7,
        )
        XCTAssertTrue(button(dragCardID).exists, "A cancelled drag must leave the selected card in hand")
        assertDoesNotExist(AccessibilityID.Battle.abilityDetail)
        origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240)))
        waitUntil("A successful drag after cancellation must play the selected card") { !self.button(dragCardID).exists }
        attachSuccessScreenshot(named: "hand-after-drag")
    }
}
