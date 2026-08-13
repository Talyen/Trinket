import TrinketFeatureSupport
import XCTest

/// Exhaustive Mystery encounter journey via deep link (kept out of smoke).
final class MysteryRecruitUITests: TrinketUITestCase {
    func testCompanionRecruitContinueReturnsToCampaign() {
        // Fresh save (no seed) so the recruit remains locked; stage 1 complete so leave unlocks stage 3.
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0",
            "-launch-screen",
            "mystery",
        ]
            + TestLaunchArg.completedStages(["chapter-1-stage-1"])
            + TestLaunchArg.mysteryRecruit(eventID: "recruit-bear"))

        assertExists(AccessibilityID.Mystery.continueButton)
        tapButton(AccessibilityID.Mystery.continueButton)
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 3))
    }
}
