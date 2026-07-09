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
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))
    }

    func testModesEntryOpensAspectsHub() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.modesEntry)
        app.buttons[AccessibilityID.Play.modesEntry].tap()
        assertExists(AccessibilityID.Play.modesScreen)
        app.buttons[AccessibilityID.Play.aspectsModeCard].tap()
        assertExists(AccessibilityID.Play.aspectsHub)
        assertExists(AccessibilityID.Play.aspectRow("ironVein"))
    }

    func testAspectClimbShowsBeginFloor() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.assertLoaded()
        app.buttons[AccessibilityID.Play.modesEntry].tap()
        app.buttons[AccessibilityID.Play.aspectsModeCard].tap()
        app.buttons[AccessibilityID.Play.aspectRow("ironVein")].tap()
        assertExists(AccessibilityID.Play.aspectClimb("ironVein"))
        assertExists(AccessibilityID.Play.aspectFloor("ironVein", floor: 1))
    }

    func testModesEntryOpensLabyrinthWhenUnlocked() {
        launchApp(arguments: chapterOneCompleteArgs)

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.modesEntry)
        app.buttons[AccessibilityID.Play.modesEntry].tap()
        assertExists(AccessibilityID.Play.modesScreen)
        app.buttons[AccessibilityID.Play.labyrinthModeCard].tap()
        assertExists(AccessibilityID.Play.labyrinthMap)
    }
}
