import XCTest

final class SmokeOptionsTests: TrinketUITestCase {
    func testOptionsTab() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))

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
}
