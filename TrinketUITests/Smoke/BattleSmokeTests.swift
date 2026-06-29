import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testBattleStartsWithPresetOneShot() {
        launchApp(arguments: [
            TestLaunchArg.resetState
        ])
        app.staticTexts["Battle"].tap()
        assertExists("Select Hero")
        app.staticTexts["Paladin"].tap()
        assertExists("Select Pet")
        app.staticTexts["Wolf"].tap()

        assertExists("Training Slime card")
        RunLoop.current.run(until: Date().addingTimeInterval(3))
        XCTAssertFalse(app.staticTexts["Victory"].exists)

        assertExists("Victory", timeout: 30)
        assertExists("Battle Again")
    }

    func testBattleCombatDetailsOpenViaSheet() {
        launchApp(arguments: [
            TestLaunchArg.resetState
        ])
        app.staticTexts["Battle"].tap()
        app.staticTexts["Paladin"].tap()
        app.staticTexts["Wolf"].tap()

        assertExists("Paladin card")
        app.buttons["Paladin card"].tap()

        assertExists("Paladin detail hero header")
        assertExists("Level 1")
        assertExists("0/100 XP")
        assertExists("Stats")
        assertExists("Health")
        assertExists("10/10")
        dismissSheet()
        assertExists("Training Slime card")
    }
}
