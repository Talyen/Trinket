import XCTest

final class SmokeItemDetailTests: TrinketUITestCase {
    func testLongswordBasicItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:longsword-basic"))
        assertExists("Longsword")
        assertExists("Affixes")
    }
}
