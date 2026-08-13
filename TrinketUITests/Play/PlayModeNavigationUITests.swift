import TrinketFeatureSupport
import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    /// Explore hub opens Spires; locked spires stay inert.
    func testExploreHubOpensSpiresWithLockedSpireInert() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
        ])

        play.assertLoaded()
        play.openExplore()

        app.buttons[AccessibilityID.Play.spiresModeCard].tap()
        assertExists(AccessibilityID.Play.spireRow("ironVein"))

        let lockedSpire = app.buttons[AccessibilityID.Play.spireRow("cinderSpire")]
        assertExists(lockedSpire)
        XCTAssertFalse(lockedSpire.isEnabled)

        app.buttons[AccessibilityID.Play.spireRow("ironVein")].tap()
        assertExists(AccessibilityID.Play.spireBeginFloor("ironVein", floor: 1))
    }

    /// Labyrinth map: reachable node opens the inspector; locked nodes stay inert.
    func testLabyrinthMapNodeInspectorInteractions() {
        launchApp(arguments: TestLaunchArg.allForScreen("labyrinth-map"))

        assertExists(AccessibilityID.Play.labyrinthMap)
        let entryNodeID = "labyrinth-cluster-1-scarCatacombs-n0"
        app.buttons[AccessibilityID.Play.labyrinthNode(entryNodeID)].tap()
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        assertExists(AccessibilityID.Play.labyrinthInspectorAction(entryNodeID))

        let lockedNodeID = "labyrinth-cluster-1-scarCatacombs-n2"
        app.buttons[AccessibilityID.Play.labyrinthNode(lockedNodeID)].tap()
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
    }
}
