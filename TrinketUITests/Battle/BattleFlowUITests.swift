import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testBattleFlowAndCombatLoops() {
        launchApp(arguments: [
            TestLaunchArg.resetState
        ])

        assertExists("Play")
        app.staticTexts["Battle"].tap()
        assertExists("Select Hero")
        app.staticTexts["Knight"].tap()
        assertExists("Select Pet")
        app.staticTexts["Wolf"].tap()

        assertExists("Battle Pause Button")
        app.buttons["Battle Pause Button"].tap()

        assertExists("Knight card")
        assertExists("Wolf card")
        assertExists("Battle Menu")

        app.buttons["Knight card"].tap()
        assertExists("Knight detail hero header")
        assertExists("Level 1")
        assertExists("0/100 XP")
        assertExists("Stats")
        assertExists("Health")
        assertExists("10/10")
        dismissSheet()

        app.tabBars.buttons["Collection"].tap()
        assertExists("Knight")
        app.tabBars.buttons["Play"].tap()

        assertExists("Victory", timeout: 30)

        assertExists("Experience")
        assertExists("Rewards")
        assertExists("Battle Again")

        app.buttons["Battle Menu"].tap()
        assertExists("Combat Log")
        XCTAssertFalse(app.buttons["Retreat"].exists)
    }
}
