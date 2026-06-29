import XCTest

final class SmokeOptionsTests: TrinketUITestCase {
    func testOptionsViaBattleMenu() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            "-battle-preset", "oneShot"
        ])
        app.staticTexts["Battle"].tap()
        app.staticTexts["Paladin"].tap()
        app.staticTexts["Wolf"].tap()

        assertExists("Victory", timeout: 5)
        app.buttons["Battle Menu"].tap()
        app.buttons["Options menu item"].tap()

        assertExists("Options Screen")
        assertExists("Theme Picker")
    }
}
