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

    func testHapticsPreferenceSurvivesSameStoreRelaunch() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        let toggle = app.switches[AccessibilityID.Options.hapticsToggle]
        assertExists(toggle)
        let before = toggle.value as? String
        XCTAssertNotNil(before)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        waitUntil("Haptics thumb must change its preference") { toggle.value as? String != before }
        let changed = toggle.value as? String
        XCTAssertNotEqual(changed, before)
        relaunchApp(arguments: ["-selectedTab", "options"])
        assertExists(app.switches[AccessibilityID.Options.hapticsToggle])
        XCTAssertEqual(app.switches[AccessibilityID.Options.hapticsToggle].value as? String, changed)
    }

    private func openReset() {
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressButton)
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressCancel, requireHittable: true)
    }
}
