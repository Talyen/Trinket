import XCTest

final class SmokePlayTests: TrinketUITestCase {
    private var chapterOneCompleteArgs: [String] {
        TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages([
            "chapter-1-stage-1",
            "chapter-1-stage-2",
            "chapter-1-stage-3",
            "chapter-1-stage-4",
            "chapter-1-stage-5",
            "chapter-1-stage-6",
            "chapter-1-stage-7",
            "chapter-1-stage-8",
            "chapter-1-stage-9",
            "chapter-1-stage-10"
        ])
    }

    func testPlayScreenLoadsWithFirstStage() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.assertChapterHeader(number: 1)
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))
    }

    /// One launch covers Mode Hub, Aspects hub/climb, and Labyrinth unlock.
    func testModesAspectsAndLabyrinthWhenChapterOneComplete() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.assertLoaded()
        play.openModeHub()
        play.assertModeHub()

        app.buttons[AccessibilityID.Play.aspectsModeCard].tap()
        assertExists(AccessibilityID.Play.aspectsHub)
        assertExists(AccessibilityID.Play.aspectRow("ironVein"))

        app.buttons[AccessibilityID.Play.aspectRow("ironVein")].tap()
        assertExists(AccessibilityID.Play.aspectClimb("ironVein"))
        assertExists(AccessibilityID.Play.aspectFloor("ironVein", floor: 1))
        goBack()
        goBack()

        play.assertModeHub()
        app.buttons[AccessibilityID.Play.labyrinthModeCard].tap()
        assertExists(AccessibilityID.Play.labyrinthMap)

        let nodePredicate = NSPredicate(format: "identifier BEGINSWITH %@", "Labyrinth Node ")
        let node = app.descendants(matching: .any).matching(nodePredicate).firstMatch
        assertExists(node)
    }
}
