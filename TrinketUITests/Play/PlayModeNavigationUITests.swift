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
        // Locked seals are inert: tapping one must neither open details nor
        // clear the selection. Guard the premise first: the seal must report
        // locked, so seed drift fails loudly instead of testing the wrong node.
        XCTAssertTrue(
            lockedNode.label.contains(", locked"),
            "Expected a locked labyrinth node, found '\(lockedNode.label)'",
        )
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
        attachVoyageScreenshot("Voyage board")
        let embark = app.buttons[AccessibilityID.Voyage.action("easy")]
        scrollUntilVisible(embark, swipingUp: true, maxAttempts: 3, requireHittable: true)
        tapWhenReady(embark)
        assertExists(AccessibilityID.Voyage.progress)
        XCTAssertEqual(app.staticTexts[AccessibilityID.Voyage.progress].label, "0 of 8 completed")
        attachVoyageScreenshot("Voyage route")
        XCTAssertFalse(app.buttons[AccessibilityID.Voyage.refresh].exists)
        tapWhenReady(app.navigationBars.buttons.firstMatch)
        scrollUntilVisible(mode, swipingUp: true, maxAttempts: 3, requireHittable: true)
        tapWhenReady(mode)
        assertExists(AccessibilityID.Voyage.progress)
        XCTAssertEqual(app.staticTexts[AccessibilityID.Voyage.progress].label, "0 of 8 completed")
        tapWhenReady(app.buttons[AccessibilityID.Voyage.options])
        tapWhenReady(app.buttons[AccessibilityID.Voyage.abandon])
        tapWhenReady(app.buttons.matching(identifier: AccessibilityID.Voyage.confirmAbandon).firstMatch)
        assertExists(AccessibilityID.Voyage.action("easy"))
        assertExists(AccessibilityID.Voyage.refresh)
    }

    private func attachVoyageScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
