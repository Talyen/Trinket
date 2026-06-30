import XCTest

final class SmokeOptionsTests: TrinketUITestCase {
    func testOptionsTab() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.tabBars.buttons["Options"].tap()

        assertExists("Options Screen")
        assertExists("Theme Picker")
    }
}
