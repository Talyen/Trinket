import TrinketFeatureSupport
import XCTest

final class SmokeShellTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("play")
    }

    func testTabShellsAreReachable() {
        play.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Play.campaignModeCard, timeout: 10)
        assertExists(AccessibilityID.Play.exploreModeCard, timeout: 10)

        tabBar.selectCollection()
        collection.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Collection.heroesCategory, timeout: 10)
        assertExists(AccessibilityID.Collection.companionsCategory, timeout: 10)

        tabBar.selectHomestead()
        homestead.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Homestead.resourceWallet, timeout: 10)

        tabBar.selectOptions()
        options.assertLoaded(timeout: 10)
        assertExists(AccessibilityID.Options.hapticsToggle, timeout: 10)

        tabBar.selectPlay()
        play.assertLoaded(timeout: 10)
    }
}

final class StarterOnboardingSmokeTests: TrinketUITestCase {
    func testStarterRouletteLandsOnGameModeHub() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            TestLaunchArg.skipOnboardingCeremony,
            "-disable-audio",
        ])

        assertExists(AccessibilityID.Onboarding.heroScreen, timeout: 20)
        XCTAssertEqual(app.tabBars.count, 0)

        let heroConfirm = app.descendants(matching: .any)[AccessibilityID.Onboarding.confirm(role: "Hero")]
        if !heroConfirm.trinketWaitForExistence(timeout: 20) {
            XCTFail("Confirm Hero not found. Tree: \(String(app.debugDescription.prefix(2500)))")
        }
        XCTAssertTrue(heroConfirm.isEnabled)
        XCTAssertNotEqual(heroConfirm.label.trimmingCharacters(in: .whitespacesAndNewlines), "Confirm Hero")
        tapWhenReady(heroConfirm)

        assertExists(AccessibilityID.Onboarding.companionScreen, timeout: 20)

        let companionConfirm = app.descendants(matching: .any)[AccessibilityID.Onboarding.confirm(role: "Companion")]
        if !companionConfirm.trinketWaitForExistence(timeout: 20) {
            XCTFail("Confirm Companion not found. Tree: \(String(app.debugDescription.prefix(2500)))")
        }
        XCTAssertTrue(companionConfirm.isEnabled)
        XCTAssertNotEqual(companionConfirm.label.trimmingCharacters(in: .whitespacesAndNewlines), "Confirm Companion")
        tapWhenReady(companionConfirm)

        XCTAssertTrue(
            app.tabBars.firstMatch.trinketWaitForExistence(timeout: 20),
            "Tab bar did not appear after onboarding",
        )
        _ = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen].trinketWaitForExistence(timeout: 20)
    }
}
