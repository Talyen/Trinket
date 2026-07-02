import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override class var launchArguments: [String] {
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
