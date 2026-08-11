import TrinketFeatureSupport
import XCTest

final class SmokePlayTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("play")
    }

    func testPlayScreenLoadsWithCampaignAndExploreChoices() {
        play.assertLoaded()
        assertExists(AccessibilityID.Play.campaignModeCard)
        assertExists(AccessibilityID.Play.exploreModeCard)
    }
}
