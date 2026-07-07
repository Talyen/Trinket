import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    func testHomesteadTabAndNodeDetail() {
        homestead.assertLoaded()
        homestead.openNode(named: "Wheat Field")
        homestead.assertNodeDetail(named: "Wheat Field")
    }
}
