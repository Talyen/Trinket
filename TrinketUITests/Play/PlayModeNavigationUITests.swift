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

        let lockedAspect = app.buttons[AccessibilityID.Play.aspectRow("cinderSpire")]
        assertExists(lockedAspect)
        XCTAssertFalse(lockedAspect.isEnabled)

        app.buttons[AccessibilityID.Play.aspectRow("ironVein")].tap()
        assertExists(AccessibilityID.Play.aspectTitle("ironVein"))
        assertExists(AccessibilityID.Play.aspectFloor("ironVein", floor: 1))
        assertExists(AccessibilityID.Play.aspectBeginFloor("ironVein", floor: 1))
        goBack()
        assertExists(AccessibilityID.Play.aspectsHub)

        goBack()
        assertExists(AccessibilityID.Play.exploreHub)

        app.buttons[AccessibilityID.Play.labyrinthModeCard].tap()
        assertExists(AccessibilityID.Play.labyrinthMap)
        assertExists(AccessibilityID.Play.labyrinthFloorMenu)
        let entryNodeID = "labyrinth-cluster-1-scarCatacombs-n0"
        let entryNode = app.buttons[AccessibilityID.Play.labyrinthNode(entryNodeID)]
        entryNode.coordinate(withNormalizedOffset: CGVector(dx: 0.86, dy: 0.5)).tap()
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        assertExists(AccessibilityID.Play.labyrinthInspectorAction(entryNodeID))

        app.buttons[AccessibilityID.Play.labyrinthNodeArtwork(entryNodeID)].tap()
        combatantDetail.assertLoaded(for: "Skeleton")
        dismissSheet()
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)

        let lockedNodeID = "labyrinth-cluster-1-scarCatacombs-n2"
        app.buttons[AccessibilityID.Play.labyrinthNode(lockedNodeID)].tap()
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)

        app.buttons[AccessibilityID.Play.labyrinthNode(entryNodeID)].tap()
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        let labyrinthMap = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthMap]
        labyrinthMap.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.15)).tap()
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
        goBack()
        assertExists(AccessibilityID.Play.exploreHub)
    }
}
