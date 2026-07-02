import XCTest

final class SmokeItemDetailTests: SeededSmokeUITestCase {
    override class var launchArguments: [String] {
        TestLaunchArg.allForScreen("item:longsword-basic")
    }

    func testLongswordBasicItemDetailRenders() {
        assertExists("Longsword")
        assertExists("Affixes")
    }
}
