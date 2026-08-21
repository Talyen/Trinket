import TrinketFeatureSupport
import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    /// Explore hub opens Spires; locked spires stay inert.
    func testExploreHubOpensSpiresWithLockedSpireInert() {
        launchApp(arguments: TestLaunchArg.allUnseeded())

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
        let entryNode = app.buttons[AccessibilityID.Play.labyrinthFloor1EntryNode]
        assertExists(entryNode)
        tapWhenReady(entryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        assertExists(
            app.buttons.matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    AccessibilityID.Play.labyrinthInspectorAction("")
                )
            ).firstMatch
        )

        let lockedNode = app.buttons[AccessibilityID.Play.labyrinthFloor1LockedNode]
        assertExists(lockedNode)
        tapWhenReady(lockedNode)
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
    }
}
