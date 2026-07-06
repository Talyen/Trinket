import XCTest

final class SmokeOptionsTests: TrinketUITestCase {
    func testOptionsTab() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))

        assertExists("Options Screen")
        assertExists("Appearance Picker")
    }

    func testThemePickerRendersViaDeepLink() {
        launchApp(arguments: TestLaunchArg.allForScreen("options"))

        assertExists("Options Screen")
        assertExists("Appearance Picker")
        assertExists("Music Volume")
        assertExists("Sound Effects Volume")
        assertExists("Haptics Toggle")
    }
}
