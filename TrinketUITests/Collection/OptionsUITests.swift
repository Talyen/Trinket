import TrinketFeatureSupport
import XCTest

final class OptionsUITests: TrinketUITestCase {
    func testResetCancellationPreservesProgressAndConfirmationClearsIt() {
        launchApp(arguments: TestLaunchArg.allForTab("options") + TestLaunchArg.completedStages(["chapter-1-stage-1"]))
        openReset()
        tapWhenReady(resetAlertAction(AccessibilityID.Options.resetProgressCancel))
        waitUntil("Reset confirmation must close") { !self.app.alerts.firstMatch.exists }
        relaunchApp()
        play.openCampaign()
        assertExists(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
        tabBar.selectOptions()
        openReset()
        tapWhenReady(resetAlertAction(AccessibilityID.Options.resetProgressConfirmation))
        assertExists(AccessibilityID.Onboarding.heroScreen)
        relaunchApp()
        assertExists(AccessibilityID.Onboarding.heroScreen)
        XCTAssertEqual(app.tabBars.count, 0)
    }

    func testHapticsPreferenceSurvivesSameStoreRelaunch() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        let toggle = app.switches[AccessibilityID.Options.hapticsToggle]
        assertExists(toggle)
        let before = toggle.value as? String
        XCTAssertNotNil(before)
        // The switch exposes the whole labeled row; target its native thumb.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).press(forDuration: 0.1)
        waitUntil("Haptics thumb must change its preference") { toggle.value as? String != before }
        let changed = toggle.value as? String
        XCTAssertNotEqual(changed, before)
        relaunchApp(arguments: ["-selectedTab", "options"])
        assertExists(app.switches[AccessibilityID.Options.hapticsToggle])
        XCTAssertEqual(app.switches[AccessibilityID.Options.hapticsToggle].value as? String, changed)
    }

    private func resetAlertAction(_ identifier: String) -> XCUIElement {
        // iOS 26.2 exposes nested native alert nodes with the same action ID and frame.
        app.alerts.firstMatch.buttons.matching(identifier: identifier).firstMatch
    }

    private func openReset() {
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressButton)
        assertExists(app.alerts.firstMatch)
        assertExists(resetAlertAction(AccessibilityID.Options.resetProgressCancel))
        assertExists(resetAlertAction(AccessibilityID.Options.resetProgressConfirmation))
    }
}
