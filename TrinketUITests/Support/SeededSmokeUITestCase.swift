import XCTest

/// Smoke tests that share one launch configuration can subclass this type to avoid
/// repeating `launchApp` in every method. Override `launchArguments` when needed.
class SeededSmokeUITestCase: TrinketUITestCase {
    var launchArguments: [String] {
        TestLaunchArg.testLaunchArgs
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        launchApp(arguments: launchArguments)
    }

    override func tearDownWithError() throws {
        if let app {
            app.terminate()
        }
        try super.tearDownWithError()
    }
}
