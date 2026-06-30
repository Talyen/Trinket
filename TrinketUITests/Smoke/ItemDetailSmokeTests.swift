import XCTest

final class SmokeItemDetailTests: TrinketUITestCase {
    func testLongswordBasicItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:longsword-basic"))
        assertExists("Longsword")
        assertExists("Placeholder")
    }

    func testPlateArmorBasicItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:plate_armor-basic"))
        assertExists("Plate Armor")
        assertExists("Placeholder")
    }

    func testRubyRingBasicItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:ruby_ring-basic"))
        assertExists("Ruby Ring")
        assertExists("Placeholder")
    }

    func testLongswordAstralItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:longsword-astral"))
        assertExists("Longsword")
        assertExists("Placeholder")
    }
}
