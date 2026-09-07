import TrinketFeatureSupport
import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    func testBattleLaunchScreenStartsStageOneOne() {
        battle.assertActive(timeout: 8)
    }

    func testContractsBoardLaunchesBattleAndReturnsAfterRetreat() {
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.assertLoaded(timeout: 10)
        play.openExplore()
        assertExistsAfterScroll(AccessibilityID.Play.contractsModeCard, requireHittable: true)
        tapButton(AccessibilityID.Play.contractsModeCard)
        assertExists(AccessibilityID.Play.contractsBoard, timeout: 10)
        for difficulty in ["easy", "standard", "hard"] {
            let partyControl = AccessibilityID.Play.contractParty(difficulty)
            assertExistsAfterScroll(partyControl, requireHittable: true)
            tapButton(partyControl)
            assertExists(AccessibilityID.Play.battlePartyDone)
            tapButton(AccessibilityID.Play.battlePartyDone)
            assertDoesNotExist(AccessibilityID.Play.battlePartyDone, timeout: 5)
        }
        scrollUntilVisible(button(AccessibilityID.Play.contractFight("standard")), swipingUp: false, requireHittable: true)

        tapButton(AccessibilityID.Play.contractsRefresh)
        assertExistsAfterScroll(AccessibilityID.Play.contractFight("standard"), requireHittable: true)
        tapButton(AccessibilityID.Play.contractFight("standard"))
        battle.assertActive(timeout: 10)
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()
        assertButtonExists(AccessibilityID.Battle.retreatConfirm)
        battle.retreatConfirmAction.tap()
        assertExists(AccessibilityID.Play.contractsBoard, timeout: 10)
        assertExistsAfterScroll(AccessibilityID.Play.contractFight("standard"), requireHittable: true)
    }
}
