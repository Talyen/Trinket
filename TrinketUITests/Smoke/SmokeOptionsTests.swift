import TrinketFeatureSupport
import XCTest

final class SmokeOptionsTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("options")
    }

    /// Canary: Options shell entry — core settings controls are reachable.
    func testOptionsLoadsCoreSettingsControls() {
        options.assertLoaded()
        assertExists("Haptics Toggle")
        assertExists("Remember Auto-Battle Preference Toggle")
        assertExists("Reset Game Progress Button")
    }
}
