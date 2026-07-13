import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    private var freshPlayArgs: [String] {
        [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0"
        ]
    }

    func testCampaignAndExploreSubModesNavigateWithExpectedBackHierarchy() {
        launchApp(arguments: freshPlayArgs)

        play.openCampaign()
        play.assertCampaignLoaded(number: 1)
        goBack()
        play.assertLoaded()

        play.openAspects()
        assertExists(AccessibilityID.Play.aspectRow("ironVein"))
        app.buttons[AccessibilityID.Play.aspectRow("ironVein")].tap()
        assertExists(AccessibilityID.Play.aspectClimb("ironVein"))
        assertExists(AccessibilityID.Play.aspectFloor("ironVein", floor: 1))

        goBack()
        assertExists(AccessibilityID.Play.aspectsHub)
        goBack()
        assertExists(AccessibilityID.Play.exploreHub)
        goBack()
        play.assertLoaded()

        play.openLabyrinth()
        let nodePredicate = NSPredicate(format: "identifier BEGINSWITH %@", "Labyrinth Node ")
        assertExists(AccessibilityID.Play.labyrinthMap)
        assertExists(app.descendants(matching: .any).matching(nodePredicate).firstMatch)

        goBack()
        assertExists(AccessibilityID.Play.exploreHub)
        goBack()
        play.assertLoaded()
    }

    func testCampaignAndExploreKeepVerticalPullsForTheirScrollViews() {
        launchApp(arguments: freshPlayArgs)

        play.openCampaign()
        app.swipeDown()
        play.assertCampaignLoaded(number: 1)

        goBack()
        play.openExplore()
        app.swipeDown()
        assertExists(AccessibilityID.Play.exploreHub)
    }
}
