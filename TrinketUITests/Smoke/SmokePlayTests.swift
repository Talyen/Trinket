import XCTest

final class SmokePlayTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0",
        ]
    }

    func testPlayScreenLoadsWithCampaignAndExploreChoices() {
        play.assertLoaded()
        assertExists(AccessibilityID.Play.campaignModeCard)
        assertExists(AccessibilityID.Play.exploreModeCard)
    }
}
