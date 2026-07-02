import XCTest

final class SmokeSearchTests: SeededSmokeUITestCase {
    override class var launchArguments: [String] {
        TestLaunchArg.allForTab("search")
    }

    func testSearchTabExists() {
        search.assertEmptyState()
    }
}
