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
