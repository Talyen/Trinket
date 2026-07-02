import XCTest

final class SmokeHomesteadTests: TrinketUITestCase {
    func testHomesteadTabExists() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        assertExists("Homestead")
    }
}
