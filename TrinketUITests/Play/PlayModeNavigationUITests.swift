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

        // Deep link may land on emptyState before `enter()` completes; tap Enter if needed.
        let enterButton = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthEnter]
        if enterButton.waitForExistence(timeout: 2) {
            tapWhenReady(enterButton)
        }
        assertExists(AccessibilityID.Play.labyrinthMap, timeout: 15)
        let entryNode = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthFloor1EntryNode]
        if !entryNode.waitForExistence(timeout: 5) {
            // Map hex layout may need a layout pulse on cold launch.
            app.swipeUp()
            app.swipeDown()
        }
        assertExists(entryNode, timeout: 15)
        tapWhenReady(entryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector, timeout: 10)
        assertExists(
            app.descendants(matching: .any).matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@",
                    AccessibilityID.Play.labyrinthInspectorAction("")
                )
            ).firstMatch
        )

        let lockedNode = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthFloor1LockedNode]
        assertExists(lockedNode)
        tapWhenReady(lockedNode)
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
    }
}
