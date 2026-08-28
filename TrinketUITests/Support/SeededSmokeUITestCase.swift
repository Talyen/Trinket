import TrinketFeatureSupport
import XCTest

class SeededSmokeUITestCase: TrinketUITestCase {
    var launchArguments: [String] {
        TestLaunchArg.testLaunchArgs
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        launchApp(arguments: launchArguments)
    }
}
