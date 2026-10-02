import TrinketFeatureSupport
import XCTest

final class OptionsUITests: TrinketUITestCase {
    func testResetCancellationPreservesProgressAndConfirmationClearsIt() {
        launchApp(arguments: TestLaunchArg.allForTab("options") + TestLaunchArg.completedStages(["chapter-1-stage-1"]))
        openReset()
        tapButton(AccessibilityID.Options.resetProgressCancel)
        relaunchApp()
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
        tabBar.selectOptions()
        openReset()
        tapButton(AccessibilityID.Options.resetProgressConfirmation)
        assertExists(AccessibilityID.Onboarding.heroScreen)
        relaunchApp()
        assertExists(AccessibilityID.Onboarding.heroScreen)
        XCTAssertEqual(app.tabBars.count, 0)
    }

    private func openReset() {
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressButton)
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressCancel, requireHittable: true)
    }
}
