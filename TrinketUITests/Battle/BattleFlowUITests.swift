import TrinketFeatureSupport
import UIKit
import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testDuoRotationPreservesBattleAndCardPlay() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["TRINKET_DUO_PROFILE"] == "1", "Requires the Duo coverage profile")
        let device = XCUIDevice.shared
        let originalOrientation = device.orientation
        defer { device.orientation = originalOrientation }

        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("60", in: TestLaunchArg.allForBattle()))
        battle.assertActive()
        let originalCards = handCardIDs
        XCTAssertFalse(originalCards.isEmpty)

        for orientation in [UIDeviceOrientation.landscapeLeft, .portrait, .landscapeRight] {
            device.orientation = orientation
            waitUntil("Rotation must preserve the hand and usable battle controls") {
                let frame = self.app.frame
                let resized = orientation.isLandscape ? frame.width > frame.height : frame.height > frame.width
                return resized && self.handCardIDs == originalCards
                    && self.battle.autoBattleToggle.isHittable && self.battle.actionsMenu.isHittable
            }
            retainScreenshot(named: "duo-battle-\(orientation.rawValue)")
        }

        let card = battle.frontmostHandCard
        let playedID = card.identifier
        tapWhenReady(card)
        waitUntil("The rotated battle must still accept card play") { !self.any(playedID).exists }
    }

    private var handCardIDs: Set<String> {
        let cards = battle.handCards
        return trinketOnMainActor {
            Set(cards.allElementsBoundByIndex.map(\.identifier))
        }
    }

    func testHandInspectionDismissalAndDragPreserveCardPlay() {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()

        let cards = battle.handCards
        let inspectedCard = battle.frontmostHandCard
        XCTAssertTrue(inspectedCard.trinketWaitForExistence(timeout: Self.defaultTimeout))
        let inspectCountBefore = cards.count
        inspectedCard.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        XCTAssertEqual(cards.count, inspectCountBefore, "Inspecting a card must not play it")
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
        dismissSheet(AccessibilityID.CombatantDetail.header(name: "Ranger"))

        let tapCard = battle.frontmostHandCard
        let tapCardID = tapCard.identifier
        tapCard.tap()
        // Draw effects can replace a played card without reducing the hand size.
        waitUntil("The first tap after dismissing details must play the card") { !self.any(tapCardID).exists }
        let dragCard = battle.frontmostHandCard
        assertExists(dragCard)
        let dragCardID = dragCard.identifier
        let origin = dragCard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        assertCancelledDrag(from: origin, cards: cards)
        origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240)))
        waitUntil("A successful drag must play the selected card") { !self.any(dragCardID).exists }
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
}
