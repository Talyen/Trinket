import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testBattleFlowAndCombatLoops() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            "-battle-preset", "oneShot"
        ])

        assertExists("Play")
        app.staticTexts["Battle"].tap()
        assertExists("Select Hero")
        app.staticTexts["Paladin"].tap()
        assertExists("Select Pet")
        app.staticTexts["Wolf"].tap()

        assertExists("Battle Pause Button")
        app.buttons["Battle Pause Button"].tap()

        assertExists("Training Slime card")
        assertExists("Paladin card")
        assertExists("Wolf card")
        assertExists("Battle Menu")

        app.buttons["Paladin card"].tap()
        assertExists("Stats")
        goBack()

        app.tabBars.buttons["Collection"].tap()
        assertExists("Paladin")
        app.tabBars.buttons["Play"].tap()
        assertExists("Training Slime card")

        app.buttons["Battle Pause Button"].tap()
        assertExists("Victory", timeout: 15)

        assertExists("Experience")
        assertExists("Rewards")
        assertExists("Battle Again")

        app.buttons["Battle Menu"].tap()
        assertExists("Combat Log")
        XCTAssertFalse(app.buttons["Retreat"].exists)
    }
}
