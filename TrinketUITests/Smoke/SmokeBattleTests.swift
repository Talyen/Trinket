import TrinketFeatureSupport
import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testVictoryContinueReturnsDirectlyToCampaign() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval(
            "0.01",
            in: TestLaunchArg.allForScreen("battle-victory"),
        ))
        let lootAll = button(AccessibilityID.Battle.continueButton)
        scrollUntilVisible(lootAll, swipingUp: true, requireHittable: true)
        tapWhenReady(lootAll)

        play.assertCampaignLoaded()
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
    }

    func testCampaignBattleRetreatReturnsDirectlyToCampaign() {
        launchApp(arguments: TestLaunchArg.allForBattle(fastTicks: true))
        battle.assertActive(timeout: 10)
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        assertExists(AccessibilityID.Battle.defeat)
        assertButtonExists(AccessibilityID.Battle.defeatLeaveButton)
        battle.defeatLeaveAction.trinketTapWhenReady()
        play.assertCampaignLoaded()
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 1))
    }
}
