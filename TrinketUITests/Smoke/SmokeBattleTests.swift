import TrinketFeatureSupport
import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testBattleLaunchScreenStartsStageOneOne() {
        launchApp(arguments: TestLaunchArg.allForBattle(fastTicks: true))
        battle.assertActive(timeout: 8)
        assertExists(battle.actionsMenu)
        XCTAssertTrue(battle.actionsMenu.isHittable, "Battle controls must remain exposed above the retained map")
        assertDoesNotExist(AccessibilityID.Play.campaignModeCard)
        assertDoesNotExist(AccessibilityID.Play.exploreModeCard)
    }

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

    func testDefeatRetryStartsBattle() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval(
            "0.01",
            in: TestLaunchArg.allUnseeded() + TestLaunchArg.screen("battle-defeat"),
        ))
        tapWhenReady(button(AccessibilityID.Battle.defeatPrimaryButton))
        battle.assertActive(timeout: 8)
    }

    func testDefeatLeaveRecoversFromSaveFailureAndReturnsToCampaign() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval(
            "0.01",
            in: TestLaunchArg.allUnseeded() + TestLaunchArg.screen("battle-defeat-save-failure"),
        ))
        tapWhenReady(button(AccessibilityID.Battle.defeatLeaveButton))
        play.assertCampaignLoaded()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 1))
    }

    func testContractsBoardLaunchesBattleAndReturnsAfterRetreat() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval(
            "0.01",
            in: TestLaunchArg.allForTab("play"),
        ))
        play.assertLoaded(timeout: 10)
        play.openExplore()
        assertExistsAfterScroll(AccessibilityID.Play.contractsModeCard, requireHittable: true)
        tapButton(AccessibilityID.Play.contractsModeCard)
        assertExists(AccessibilityID.Play.contractsBoard, timeout: 10)
        let partyControl = AccessibilityID.Play.contractParty("standard")
        assertExistsAfterScroll(partyControl, requireHittable: true)
        tapButton(partyControl)
        assertExists(AccessibilityID.Play.battlePartyDone)
        tapButton(AccessibilityID.Play.battlePartyDone)
        assertDoesNotExist(AccessibilityID.Play.battlePartyDone, timeout: 5)
        assertExistsAfterScroll(AccessibilityID.Play.contractFight("standard"), requireHittable: true)
        tapButton(AccessibilityID.Play.contractFight("standard"))
        battle.assertActive(timeout: 10)
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        assertExists(AccessibilityID.Battle.defeat)
        assertButtonExists(AccessibilityID.Battle.defeatPrimaryButton)
        assertButtonExists(AccessibilityID.Battle.defeatLeaveButton)
        battle.defeatLeaveAction.trinketTapWhenReady()
        assertExists(AccessibilityID.Play.contractsBoard, timeout: 10)
        assertExistsAfterScroll(AccessibilityID.Play.contractFight("standard"), requireHittable: true)
    }
}
