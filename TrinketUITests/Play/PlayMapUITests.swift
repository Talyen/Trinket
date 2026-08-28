import TrinketFeatureSupport
import XCTest

final class PlayMapUITests: TrinketUITestCase {
    func testBattleUsesCompactPartyPicker() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openCampaign()

        button(AccessibilityID.Play.stagePartyControl).tap()
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)

        let heroOptionID = AccessibilityID.Play.battlePartyOption(
            for: "Hero",
            combatantID: "rogue"
        )
        assertExists(heroOptionID)
        button(heroOptionID).tap()

        button(AccessibilityID.Play.battlePartyDone).tap()
        assertDoesNotExist(AccessibilityID.Play.stagePartyPickerSheet, timeout: 5)
    }
}
