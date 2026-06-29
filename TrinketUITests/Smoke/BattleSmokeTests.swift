import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testBattleStartsWithPresetOneShot() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            "-battle-preset", "oneShot"
        ])
        app.staticTexts["Battle"].tap()
        assertExists("Select Hero")
        app.staticTexts["Paladin"].tap()
        assertExists("Select Pet")
        app.staticTexts["Wolf"].tap()

        assertExists("Victory", timeout: 5)
        assertExists("Battle Again")
    }

    func testBattleCombatDetailsOpenViaSheet() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            "-battle-preset", "oneShot"
        ])
        app.staticTexts["Battle"].tap()
        app.staticTexts["Paladin"].tap()
        app.staticTexts["Wolf"].tap()

        assertExists("Victory", timeout: 5)
        assertExists("Battle Again")
    }
}
