import TrinketFeatureSupport
import XCTest

final class OptionsUITests: TrinketUITestCase {
    func testResetCancellationPreservesProgressAndConfirmationClearsIt() {
        launchApp(arguments: TestLaunchArg.allForTab("options") + TestLaunchArg.completedStages(["chapter-1-stage-1"]))
        openReset()
        tapWhenReady(resetAlertAction(AccessibilityID.Options.resetProgressCancel))
        waitUntil("Reset confirmation must close") { !self.app.alerts.firstMatch.exists }
        tabBar.select(.play)
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
        tabBar.select(.options)
        openReset()
        tapWhenReady(resetAlertAction(AccessibilityID.Options.resetProgressConfirmation))
        assertExists(AccessibilityID.Onboarding.heroScreen)
        relaunchApp()
        assertExists(AccessibilityID.Onboarding.heroScreen)
    }

    private func resetAlertAction(_ identifier: String) -> XCUIElement {
        // iOS 26.2 exposes nested native alert nodes with the same action ID and frame.
        app.alerts.firstMatch.buttons.matching(identifier: identifier).firstMatch
    }

    private func openReset() {
        tapButtonAfterScroll(AccessibilityID.Options.resetProgressButton)
        assertExists(app.alerts.firstMatch)
    }
}
