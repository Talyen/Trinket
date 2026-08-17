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
        let entryNode = labyrinthFloorNode(index: 0)
        assertExists(entryNode)
        tapWhenReady(entryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        assertExists(AccessibilityID.Play.labyrinthInspectorAction(labyrinthNodeID(from: entryNode)))

        let lockedNode = labyrinthFloorNode(index: 2)
        assertExists(lockedNode)
        tapWhenReady(lockedNode)
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
    }

    /// Floor-1 node IDs include the generated biome (`labyrinth-cluster-1-<biome>-nN`).
    private func labyrinthFloorNode(index: Int) -> XCUIElement {
        app.buttons.matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                AccessibilityID.Play.labyrinthNode("labyrinth-cluster-1-"),
                "-n\(index)"
            )
        ).firstMatch
    }

    private func labyrinthNodeID(from node: XCUIElement) -> String {
        let prefix = AccessibilityID.Play.labyrinthNode("")
        let identifier = node.identifier
        if identifier.hasPrefix(prefix) {
            return String(identifier.dropFirst(prefix.count))
        }
        return identifier
    }
}
