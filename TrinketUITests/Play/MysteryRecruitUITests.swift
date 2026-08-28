import TrinketFeatureSupport
import XCTest

final class MysteryRecruitUITests: TrinketUITestCase {
    func testCompanionRecruitContinueReturnsToCampaign() {
        launchApp(arguments: TestLaunchArg.allUnseeded()
            + ["-battle-tick-interval", "1.0"]
            + TestLaunchArg.screen("mystery")
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear"))

        assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
        assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertDoesNotExist(AccessibilityID.Mystery.unlockCard(name: "Bear"), timeout: 8)
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 3))
    }
}
