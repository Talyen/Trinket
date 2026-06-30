import XCTest

final class SmokeItemDetailTests: TrinketUITestCase {
    func testLongswordBasicItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:longsword-basic"))
        assertExists("Longsword")
        assertExists("Affixes")
    }

    func testPlateArmorBasicItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:plate_armor-basic"))
        assertExists("Plate Armor")
        assertExists("Affixes")
    }

    func testRubyRingBasicItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:ruby_ring-basic"))
        assertExists("Ruby Ring")
        assertExists("Affixes")
    }

    func testLongswordAstralItemDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:longsword-astral"))
        assertExists("Longsword")
        assertExists("Affixes")
    }
}
