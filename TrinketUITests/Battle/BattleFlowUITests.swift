import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testBattleFlowAndCombatLoops() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        assertExists("Play")
        app.buttons["Stage 1-1 Node"].tap()
        assertExists("Battle Button")
        app.buttons["Battle Button"].tap()

        assertExists("Battle Pause Button")

        assertExists("Knight card")
        assertExists("Wolf card")
        assertExists("Battle Menu")

        app.buttons["Knight card"].tap()
        let knightHeader = app.descendants(matching: .any)["Knight detail hero header"]
        assertExists(knightHeader)
        XCTAssertEqual(knightHeader.label, "Knight, Hero, level 2, 35 of 120 experience")
        assertExists("Stats")
        assertExists("Health")
        dismissSheet()

        app.tabBars.buttons["Collection"].tap()
        assertExists("Knight")
        app.tabBars.buttons["Play"].tap()

        assertExists("Victory", timeout: 15)

        assertExists("Experience")
        assertExists("Rewards")
        assertExists("Continue Button")

        app.buttons["Battle Menu"].tap()
        assertExists("Combat Log")
        XCTAssertFalse(app.buttons["Retreat"].exists)
    }
}
