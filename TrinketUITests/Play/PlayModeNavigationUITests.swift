import TrinketFeatureSupport
import XCTest

final class PlayModeNavigationUITests: TrinketUITestCase {
    func testExploreHubOpensSpiresWithLockedSpireInert() {
        launchApp(arguments: TestLaunchArg.allUnseeded())

        play.assertLoaded()
        play.openExplore()

        tapButton(AccessibilityID.Play.spiresModeCard)
        assertExists(AccessibilityID.Play.spireRow("ironVein"))

        let lockedSpire = app.buttons[AccessibilityID.Play.spireRow("cinderSpire")]
        assertExists(lockedSpire)
        XCTAssertFalse(lockedSpire.isEnabled)

        tapButton(AccessibilityID.Play.spireRow("ironVein"))
        assertExists(AccessibilityID.Play.spireBeginFloor("ironVein", floor: 1))
    }

    func testLabyrinthMapNodeInspectorInteractions() {
        launchApp(arguments: TestLaunchArg.allForScreen("labyrinth-map"))

        let enterButton = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthEnter]
        if enterButton.trinketWaitForExistence(timeout: 3) {
            tapWhenReady(enterButton)
        }
        assertExists(AccessibilityID.Play.labyrinthMap, timeout: 20)
        let entryNode = waitForLabyrinthEntryNode()
        tapWhenReady(entryNode)
        assertExists(AccessibilityID.Play.labyrinthNodeInspector, timeout: 15)
        let inspectorAction = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", AccessibilityID.Play.labyrinthInspectorAction("")),
        ).firstMatch
        assertExists(inspectorAction, timeout: 10)

        let lockedNode = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthFloor1LockedNode].firstMatch
        assertExists(lockedNode)
        // Guard the premise before checking that a locked seal leaves the
        // current selection intact. XCUITest reports this SwiftUI node as
        // enabled even while its action is disabled.
        XCTAssertTrue(lockedNode.label.contains(", locked"), "Expected a locked labyrinth node")
        lockedNode.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        assertExists(inspectorAction, timeout: 10)

        // Dismissal belongs to the background dismiss control, not to node taps.
        app.descendants(matching: .any)[AccessibilityID.Play.labyrinthDismissSelection]
            .coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))
            .tap()
        assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
    }

    func testVoyageEmbarkResumeAndAbandon() {
        launchApp(arguments: TestLaunchArg.allUnseeded())
        play.openExplore()
        let mode = app.buttons[AccessibilityID.Voyage.modeCard]
        scrollUntilVisible(mode, swipingUp: true, maxAttempts: 4, requireHittable: true)
        tapWhenReady(mode)
        assertExists(AccessibilityID.Voyage.screen)
        attachSuccessScreenshot(named: "Voyage board")
        let embark = app.buttons[AccessibilityID.Voyage.action("easy")]
        scrollUntilVisible(embark, swipingUp: true, maxAttempts: 3, requireHittable: true)
        tapWhenReady(embark)
        assertExists(AccessibilityID.Voyage.destinationReward)
        let reward = app.descendants(matching: .any)[AccessibilityID.Voyage.destinationReward].label
        XCTAssertFalse(reward.isEmpty, "Embarking must show the destination reward")
        attachSuccessScreenshot(named: "Voyage route")
        XCTAssertFalse(app.buttons[AccessibilityID.Voyage.refresh].exists)
        goBack()
        scrollUntilVisible(mode, swipingUp: true, maxAttempts: 3, requireHittable: true)
        tapWhenReady(mode)
        assertExists(AccessibilityID.Voyage.destinationReward)
        XCTAssertEqual(app.descendants(matching: .any)[AccessibilityID.Voyage.destinationReward].label, reward)
        tapWhenReady(app.buttons[AccessibilityID.Voyage.options])
        tapWhenReady(app.buttons[AccessibilityID.Voyage.abandon])
        tapWhenReady(app.buttons.matching(identifier: AccessibilityID.Voyage.confirmAbandon).firstMatch)
        assertExists(AccessibilityID.Voyage.action("easy"))
        assertExists(AccessibilityID.Voyage.refresh)
    }

    private func waitForLabyrinthEntryNode() -> XCUIElement {
        let entryNode = app.descendants(matching: .any)[AccessibilityID.Play.labyrinthFloor1EntryNode]
        if entryNode.trinketWaitForExistence(timeout: 10) {
            return entryNode
        }
        // Map tiles lay out asynchronously; one recovery scroll before the final bounded wait.
        app.swipeUp()
        app.swipeDown()
        assertExists(entryNode, timeout: 10)
        return entryNode
    }
}
