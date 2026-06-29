import XCTest

final class SmokeOptionsTests: TrinketUITestCase {
    func testOptionsTab() {
        launchApp(arguments: [
            TestLaunchArg.resetState
        ])
        app.tabBars.buttons["Options"].tap()

        assertExists("Options Screen")
        assertExists("Theme Picker")
    }
}
