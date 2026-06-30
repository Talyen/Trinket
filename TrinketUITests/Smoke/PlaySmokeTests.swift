import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayMapRendersChapterOne() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        assertExists("Play")
        assertExists("The Verdant Forest")
        assertExists("Stage 1-1 Node")
        assertExists("Chapter 2 Locked")
    }

    func testActiveStagePreviewAppears() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        app.buttons["Stage 1-1 Node"].tap()

        assertExists("Stage Preview Header")
        let header = app.descendants(matching: .any)["Stage Preview Header"]
        XCTAssertTrue(header.label.contains("Enemy"))
        assertExists("Stage 1-1")
        assertExists("Goblin")
        assertExists("Party")
        assertExists("Selected Hero Card")
        assertExists("Selected Pet Card")
        assertExists("Battle Button")
        XCTAssertFalse(app.staticTexts["Possible Rewards"].exists)
    }

    func testFutureStageShowsLockedFeedback() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        app.buttons["Stage 1-2 Node"].tap()

        assertExists("Stage Locked")
        app.alerts.buttons["OK"].tap()
        XCTAssertFalse(app.buttons["Battle Button"].exists)
    }

    func testNonBattleStubStageCanComplete() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs + TestLaunchArg.completedStages(["chapter-1-stage-1"]))

        app.buttons["Stage 1-2 Node"].tap()
        assertExists("Stage Preview Header")
        let header = app.descendants(matching: .any)["Stage Preview Header"]
        assertExists("Stage 1-2")
        XCTAssertTrue(header.label.contains("Mystery"))
        assertExists("Continue Button")
        app.buttons["Continue Button"].tap()

        assertExists("Stage 1-3 Node")
        app.buttons["Stage 1-2 Node"].tap()
        assertExists("Stage Complete")
        app.alerts.buttons["OK"].tap()
    }
}
