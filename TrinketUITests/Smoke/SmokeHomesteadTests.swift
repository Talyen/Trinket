import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    func testHomesteadTabExists() {
        homestead.assertLoaded()
    }

    func testHomesteadNodeOpensDetail() {
        homestead.openNode(named: "Wheat Field")
        homestead.assertNodeDetail(named: "Wheat Field")
    }
}
