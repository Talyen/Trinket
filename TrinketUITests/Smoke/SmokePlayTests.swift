import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayMapRendersChapterOne() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.assertChapterHeader(number: 1)
        assertButtonExists("Stage 1-1 Node")
        XCTAssertFalse(any("Chapter 2 Locked").exists)
    }

    func testActiveStagePreviewAppears() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.openStage("Stage 1-1 Node")

        assertExists("Stage Preview Header")
        let header = any("Stage Preview Header")
        XCTAssertTrue(header.label.contains("Enemy"))
        assertExists("Stage 1-1")
        assertExists("Skeleton")
        assertExists("Party")
        assertExists("Selected Hero Card")
        assertExists("Selected Pet Card")
        assertButtonExists("Battle Button")
        XCTAssertFalse(app.staticTexts["Possible Rewards"].exists)
    }

    func testNonBattleStubStageCanComplete() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        play.openStage("Stage 1-2 Node")
        assertExists("Stage Preview Header")
        let header = any("Stage Preview Header")
        assertExists("Stage 1-2")
        XCTAssertTrue(header.label.contains("Mystery"))
        assertButtonExists("Continue Button")
        button("Continue Button").tap()

        assertButtonExists("Stage 1-3 Node")
        XCTAssertFalse(button("Stage 1-2 Node").exists)
        assertExists("Stage 1-2 Node")
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
