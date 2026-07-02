import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayMapRendersChapterOne() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.assertChapterHeader(number: 1)
        assertButtonExists("Stage 1-1 Node")
        assertExistsAfterScroll("Chapter 2 Locked")
    }

    func testActiveStageLaunchesBattleInline() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openStage("Stage 1-1 Node")

        assertButtonExists("Battle Pause Button")
        assertExists("Knight card")
        assertExists("Wolf card")
        XCTAssertFalse(app.staticTexts["Possible Rewards"].exists)
    }

    func testNonBattleStubStageCanComplete() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        play.openStage("Stage 1-2 Node")

        assertButtonExists("Stage 1-3 Node")
        XCTAssertFalse(button("Stage 1-2 Node").exists)
        XCTAssertFalse(app.descendants(matching: .any)["Stage 1-2 Node"].exists)
        XCTAssertFalse(app.alerts.element.exists)
    }

    func testFinalStageShowsLockedNextChapter() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages([
            "chapter-1-stage-1",
            "chapter-1-stage-2",
            "chapter-1-stage-3",
            "chapter-1-stage-4",
            "chapter-1-stage-5",
            "chapter-1-stage-6",
            "chapter-1-stage-7",
            "chapter-1-stage-8",
            "chapter-1-stage-9"
        ]))

        assertButtonExists("Stage 1-10 Node")
        assertExists("Chapter 2 Locked")
    }
}
