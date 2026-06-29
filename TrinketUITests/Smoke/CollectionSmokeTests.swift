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
        assertExists("Knight collection card")
        assertExists("Wizard collection card")
        assertExists("Rogue collection card")
    }

    func testHeroDetailOpens() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Collection"].tap()
        app.buttons["Heroes collection category"].tap()
        app.buttons["Knight collection card"].tap()
        assertExists("Knight detail hero header")
    }
}
