import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testBattleStartsWithPresetOneShot() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.buttons["Stage 1-1 Node"].tap()
        assertExists("Battle Button")
        app.buttons["Battle Button"].tap()

        assertExists("Battle Pause Button")
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        XCTAssertFalse(app.staticTexts["Victory"].exists)

        assertExists("Victory", timeout: 30)
        assertExists("Continue")
    }

    func testBattleCombatDetailsOpenViaSheet() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.buttons["Stage 1-1 Node"].tap()
        assertExists("Battle Button")
        app.buttons["Battle Button"].tap()

        assertExists("Knight card")
        app.buttons["Knight card"].tap()

        let header = app.descendants(matching: .any)["Knight detail hero header"]
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        XCTAssertEqual(header.label, "Knight, Hero, level 2, 35 of 120 experience")
        assertExists("Stats")
        assertExists("Health")
        assertExists("10/10")
        dismissSheet()
        assertExists("Battle Pause Button")
    }
}
