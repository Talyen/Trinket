import TrinketFeatureSupport
import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testCampaignVictoryAndClaimUnlockTheNextStage() {
        launchApp(arguments: TestLaunchArg.allForTab("play")
            + ["-performance-strong-party", TestLaunchArg.rewardCheckpoint])
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()
        tapWhenReady(battle.autoBattleToggle)
        assertExists(AccessibilityID.Battle.victory, timeout: 30)
        let lootAll = button(AccessibilityID.Battle.continueButton)
        XCTAssertTrue(app.scrollUntilVisible(lootAll, swipingUp: true, requireHittable: true), "The claim must be reachable")
        lootAll.doubleTap()
        assertExists(AccessibilityID.Debug.rewardCollectionCheckpoint)
        backgroundAndActivate()

        play.assertCampaignLoaded()
        tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.encounterTitle)
    }

    func testBackgroundedProductionBattleAcceptsRapidCardsDragAndExit() throws {
        launchApp(arguments: TestLaunchArg.productionTiming())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()
        backgroundAndActivate()
        let cards = battle.handCards
        let cardIDs = trinketOnMainActor { cards.allElementsBoundByIndex.map(\.identifier) }
        let firstID = try XCTUnwrap(cardIDs.last)
        let secondID = try XCTUnwrap(cardIDs.dropLast().last)
        XCTAssertNotEqual(firstID, secondID, "Rapid plays must target two distinct cards")
        tapWhenReady(button(firstID))
        tapWhenReady(button(secondID))
        waitUntil("Distinct rapid plays must depart from the hand") {
            !self.button(firstID).exists && !self.button(secondID).exists
        }
        let drag = battle.frontmostHandCard
        assertExists(drag)
        let dragID = drag.identifier
        let origin = drag.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240)))
        waitUntil("Drag following rapid casts must still play") { !self.button(dragID).exists }
        battle.openActions()
        tapButton(AccessibilityID.Battle.retreat)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        assertExists(AccessibilityID.Battle.defeat)
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
    }
}
