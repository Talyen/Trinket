import TrinketFeatureSupport
import XCTest

/// Exhaustive Mystery encounter journey via deep link (kept out of smoke).
final class MysteryRecruitUITests: TrinketUITestCase {
    func testCompanionRecruitContinueReturnsToCampaign() {
        // Fresh save (no seed) so the recruit remains locked; stage 1 complete so leave unlocks stage 3.
        launchApp(arguments: TestLaunchArg.allUnseeded()
            + ["-battle-tick-interval", "1.0"]
            + TestLaunchArg.screen("mystery")
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear"))

        // Recruit stays accessibility-hidden until the ceremony finishes, then seal-dismisses.
        assertExists(AccessibilityID.Mystery.unlockCard(name: "Bear"))
        assertExistsAfterScroll(AccessibilityID.Mystery.continueButton, requireHittable: true)
        tapButton(AccessibilityID.Mystery.continueButton)
        assertDoesNotExist(AccessibilityID.Mystery.unlockCard(name: "Bear"), timeout: 8)
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 3))
    }
}
