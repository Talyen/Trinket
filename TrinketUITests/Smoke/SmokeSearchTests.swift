import XCTest

final class SmokeSearchTests: TrinketUITestCase {
    func testSearchTabExists() {
        launchApp(arguments: TestLaunchArg.allForTab("search"))
        assertExists("Heroes, Pets, and Items")
    }
}
