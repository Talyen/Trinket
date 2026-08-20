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
    func testStarterChoicesEnterCampaignWithNoInitialSelection() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
        ])

        assertExists(AccessibilityID.Onboarding.heroScreen)
        XCTAssertEqual(app.tabBars.count, 0)
        let heroConfirm = app.buttons[AccessibilityID.Onboarding.confirm(role: "Hero")]
        assertExists(heroConfirm)
        XCTAssertFalse(heroConfirm.isEnabled)

        let wizard = app.buttons[
            AccessibilityID.Onboarding.option(role: "Hero", combatantID: "wizard")
        ]
        wizard.press(forDuration: 0.6)
        assertExists(AccessibilityID.Onboarding.detail(combatantID: "wizard"))
        dismissSheet()

        tapWhenReady(wizard)
        XCTAssertTrue(heroConfirm.isEnabled)
        tapButton(AccessibilityID.Onboarding.confirm(role: "Hero"))

        assertExists(AccessibilityID.Onboarding.companionScreen)
        let companionConfirm = app.buttons[AccessibilityID.Onboarding.confirm(role: "Companion")]
        assertExists(companionConfirm)
        XCTAssertFalse(companionConfirm.isEnabled)

        tapButton(AccessibilityID.Onboarding.option(role: "Companion", combatantID: "frost_whelp"))
        XCTAssertTrue(companionConfirm.isEnabled)
        tapButton(AccessibilityID.Onboarding.confirm(role: "Companion"))

        assertExists(AccessibilityID.Play.stageRow(chapter: 1, stage: 1))
        XCTAssertGreaterThan(app.tabBars.count, 0)
    }
}
