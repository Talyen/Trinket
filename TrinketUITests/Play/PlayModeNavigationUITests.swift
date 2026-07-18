import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    /// Explore hub is reachable from Play; Aspects and Labyrinth open from Explore.
    func testExploreHubReachesAspectsAndLabyrinth() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-battle-tick-interval",
            "1.0"
        ])

        play.assertLoaded()
        play.openExplore()
        assertExists(AccessibilityID.Play.exploreHub)

        app.buttons[AccessibilityID.Play.aspectsModeCard].tap()
        assertExists(AccessibilityID.Play.aspectRow("ironVein"))
        goBack()
        assertExists(AccessibilityID.Play.exploreHub)

        app.buttons[AccessibilityID.Play.labyrinthModeCard].tap()
        assertExists(AccessibilityID.Play.labyrinthMap)
        goBack()
        assertExists(AccessibilityID.Play.exploreHub)
    }
}
