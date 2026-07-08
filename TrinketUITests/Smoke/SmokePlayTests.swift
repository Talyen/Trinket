import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayScreenLoadsWithFirstStage() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        assertButtonExists("Stage 1-1 Node")
    }
}
