import TrinketFeatureSupport
import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testCampaignCardPlayVictoryAndClaimUnlockTheNextStage() {
        launchApp(arguments: TestLaunchArg.allForTab("play")
            + ["-performance-strong-party", TestLaunchArg.rewardCheckpoint])
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.assertActive()
        let card = battle.frontmostHandCard
        assertExists(card)
        let playedID = card.identifier
        tapWhenReady(card)
        waitUntil("Manual card play must consume the selected card") {
            !self.any(playedID).exists || self.any(AccessibilityID.Battle.victory).exists
        }
        if battle.autoBattleToggle.exists {
            tapWhenReady(battle.autoBattleToggle)
        }
        assertExists(AccessibilityID.Battle.victory, timeout: 30)
        let lootAll = button(AccessibilityID.Battle.continueButton)
        scrollUntilVisible(lootAll, swipingUp: true, requireHittable: true)
        lootAll.doubleTap()
        assertExists(AccessibilityID.Debug.rewardCollectionCheckpoint)
        backgroundAndActivate()

        play.assertCampaignLoaded()
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
        tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.encounterTitle)
    }

    func testCampaignBattleRetreatReturnsDirectlyToCampaign() {
        launchApp(arguments: TestLaunchArg.allForBattle(fastTicks: true))
        battle.assertActive(timeout: 10)
        battle.openActions()
        tapButton(AccessibilityID.Battle.retreat)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        assertExists(AccessibilityID.Battle.defeat)
        tapButton(AccessibilityID.Battle.defeatLeaveButton)
        play.assertCampaignLoaded()
        assertDoesNotExist(AccessibilityID.Battle.autoBattleToggle)
        assertDoesNotExist(AccessibilityID.Battle.actionsMenu)
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 1))
    }
}
