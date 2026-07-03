import XCTest

final class SmokeSearchTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("search")
    }

    func testSearchTabExists() {
        search.assertEmptyState()
    }
}
