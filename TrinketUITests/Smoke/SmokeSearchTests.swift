import XCTest

final class SmokeSearchTests: TrinketUITestCase {
    func testSearchTabExists() {
        launchApp(arguments: TestLaunchArg.allForTab("search"))
        search.assertEmptyState()
    }
}
