import XCTest

final class SmokeOptionsTests: TrinketUITestCase {
    func testOptionsTab() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.tabBars.buttons["Options"].tap()

        assertExists("Options Screen")
        assertExists("Theme Picker")
    }

    func testThemePickerRendersViaDeepLink() {
        launchApp(arguments: TestLaunchArg.allForScreen("options"))

        assertExists("Options Screen")
        assertExists("Theme Picker")
        assertExists("Music Volume")
        assertExists("Sound Effects Volume")
        assertExists("Haptics Toggle")
    }

    func testThemePickerSelectionUpdates() {
        launchApp(arguments: TestLaunchArg.allForScreen("options"))

        let themePicker = app.segmentedControls["Theme Picker"]
        assertExists(themePicker)

        themePicker.buttons["Dark"].tap()
        XCTAssertTrue(themePicker.buttons["Dark"].isSelected)

        themePicker.buttons["Light"].tap()
        XCTAssertTrue(themePicker.buttons["Light"].isSelected)

        themePicker.buttons["System"].tap()
        XCTAssertTrue(themePicker.buttons["System"].isSelected)
    }
}
