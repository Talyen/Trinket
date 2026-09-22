import TrinketFeatureSupport
import XCTest

final class PlayMapUITests: TrinketUITestCase {
    func testBattleUsesCompactPartyPicker() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openCampaign()

        tapButton(AccessibilityID.Play.stagePartyControl)
        assertExists(AccessibilityID.Play.stagePartyPickerSheet)

        let heroOptionID = AccessibilityID.Play.battlePartyOption(
            for: "Hero",
            combatantID: "rogue",
        )
        assertExists(heroOptionID)
        tapButton(heroOptionID)

        tapButton(AccessibilityID.Play.battlePartyDone)
        assertDoesNotExist(AccessibilityID.Play.stagePartyPickerSheet, timeout: 5)
        tapButton(AccessibilityID.Play.stagePartyControl)
        assertExists(heroOptionID)
        XCTAssertTrue(button(heroOptionID).isSelected, "The chosen Rogue must remain selected when the party picker reopens")
    }
}
