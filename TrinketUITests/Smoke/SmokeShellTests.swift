import TrinketFeatureSupport
import XCTest

/// One launch covering the four tab shells via the real tab bar.
final class SmokeShellTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("play")
    }

    func testTabShellsAreReachable() {
        play.assertLoaded()
        assertExists(AccessibilityID.Play.campaignModeCard)
        assertExists(AccessibilityID.Play.exploreModeCard)

        tabBar.selectCollection()
        collection.assertLoaded()
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.companionsCategory)

        tabBar.selectHomestead()
        homestead.assertLoaded()
        assertExists(AccessibilityID.Homestead.resourceWallet)

        tabBar.selectOptions()
        options.assertLoaded()
        assertExists(AccessibilityID.Options.hapticsToggle)

        tabBar.selectPlay()
        play.assertLoaded()
    }
}

final class StarterOnboardingSmokeTests: TrinketUITestCase {
    func testStarterRouletteLandsOnGameModeHub() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            TestLaunchArg.skipOnboardingCeremony,
            "-disable-audio",
            "-persist-save-immediately",
        ])

        assertExists(AccessibilityID.Onboarding.heroScreen)
        XCTAssertEqual(app.tabBars.count, 0)

        let heroConfirm = app.descendants(matching: .any)[AccessibilityID.Onboarding.confirm(role: "Hero")]
        if !heroConfirm.waitForExistence(timeout: 10) {
            XCTFail("Confirm Hero not found. Tree: \(String(app.debugDescription.prefix(2500)))")
        }
        // The carousel opens on the first combatant; Confirm must name that
        // combatant, never the bare-role no-selection fallback.
        XCTAssertNotEqual(heroConfirm.label, "Confirm Hero")
        tapWhenReady(heroConfirm)

        assertExists(AccessibilityID.Onboarding.companionScreen, timeout: 10)

        let companionConfirm = app.descendants(matching: .any)[AccessibilityID.Onboarding.confirm(role: "Companion")]
        if !companionConfirm.waitForExistence(timeout: 10) {
            XCTFail("Confirm Companion not found. Tree: \(String(app.debugDescription.prefix(2500)))")
        }
        XCTAssertNotEqual(companionConfirm.label, "Confirm Companion")
        tapWhenReady(companionConfirm)

        // Onboarding completes with a crossfade to the Play hub.
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Tab bar did not appear after onboarding"
        )
        // The hub's container is the stable signal; give the Play screen a moment to settle.
        _ = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen].waitForExistence(timeout: 5)
    }
}
