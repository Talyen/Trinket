import XCTest

final class SmokeCollectionTests: TrinketUITestCase {
    func testCollectionScreenRenders() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Collection"].tap()
        assertExists("Heroes collection category")
        assertExists("Pets collection category")
        assertExists("Inventory collection category")
    }

    func testHeroesGridRenders() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Collection"].tap()
        app.buttons["Heroes collection category"].tap()
        assertExists("Paladin collection card")
        assertExists("Mage collection card")
        assertExists("Rogue collection card")
    }

    func testHeroDetailOpens() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Collection"].tap()
        app.buttons["Heroes collection category"].tap()
        app.buttons["Paladin collection card"].tap()
        assertExists("Paladin detail hero header")
    }
}
