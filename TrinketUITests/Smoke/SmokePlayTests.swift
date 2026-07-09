import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayScreenLoadsWithFirstStage() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))
    }

    func testModesEntryOpensAspectsHub() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.modesEntry)
        app.buttons[AccessibilityID.Play.modesEntry].tap()
        assertExists(AccessibilityID.Play.modesScreen)
        app.buttons[AccessibilityID.Play.aspectsModeCard].tap()
        assertExists(AccessibilityID.Play.aspectsHub)
        assertExists(AccessibilityID.Play.aspectRow("ironVein"))
    }

    func testModesEntryOpensLabyrinthWhenUnlocked() {
        let chapterOneStages = (1 ... 10).map { "chapter-1-stage-\($0)" }
        launchApp(
            arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages(chapterOneStages)
        )

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.modesEntry)
        app.buttons[AccessibilityID.Play.modesEntry].tap()
        assertExists(AccessibilityID.Play.modesScreen)
        app.buttons[AccessibilityID.Play.labyrinthModeCard].tap()
        assertExists(AccessibilityID.Play.labyrinthMap)
    }
}
