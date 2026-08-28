import TrinketFeatureSupport
import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
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

    func testLabyrinthMapNodeInspectorInteractions() {
        launchApp(arguments: TestLaunchArg.allForScreen("labyrinth-map"))

        let enterButton = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthEnter]
        if enterButton.waitForExistence(timeout: 3) {
            tapWhenReady(enterButton)
        }
        assertExists(AccessibilityID.Play.labyrinthMap, timeout: 20)
        let entryNode = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthFloor1EntryNode]
        if !entryNode.waitForExistence(timeout: 10) {
            assertExists(AccessibilityID.Play.labyrinthMap, timeout: 5)
            app.swipeUp()
            app.swipeDown()
            _ = entryNode.waitForExistence(timeout: 5)
        }
        assertExists(entryNode, timeout: 20)
        tapWhenReady(entryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector, timeout: 15)
        let inspectorAction = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction(""))
        ).firstMatch
        assertExists(inspectorAction, timeout: 10)

        let lockedNode = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthFloor1LockedNode]
        assertExists(lockedNode)
        tapWhenReady(lockedNode)
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
    }
}
