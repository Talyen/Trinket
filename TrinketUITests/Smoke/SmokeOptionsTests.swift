import XCTest

final class SmokeOptionsTests: TrinketUITestCase {
    func testOptionsScreenRenders() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))

        assertExists("Options Screen")
        assertExists("Appearance Picker")
        assertExists("Music Volume")
        assertExists("Sound Effects Volume")
        assertExists("Haptics Toggle")
    }
}
