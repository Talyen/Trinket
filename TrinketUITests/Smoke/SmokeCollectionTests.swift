import XCTest

final class SmokeCollectionTests: TrinketUITestCase {
    func testCollectionScreenRenders() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.tabBars.buttons["Collection"].tap()
        assertExists("Heroes collection category")
        assertExists("Pets collection category")
        assertExists("Inventory collection category")
    }

    func testHeroesGridRenders() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.tabBars.buttons["Collection"].tap()
        app.buttons["Heroes collection category"].tap()
        assertExists("Knight collection card")
        assertExists("Wizard collection card")
        assertExists("Rogue collection card")
    }

    func testFreshStartItemSlotsRenderLockedUntilSlotItemExists() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync
        ] + TestLaunchArg.screen("hero:knight"))

        scrollUntilVisible(app.descendants(matching: .any)["Weapon item slot"], swipingUp: true)
        assertExists("Find a Weapon to Unlock")
        assertExists("Find Armor to Unlock")
        assertExists("Find a Trinket to Unlock")

        app.descendants(matching: .any)["Weapon item slot"].tap()
        XCTAssertFalse(app.navigationBars["Equip Weapon"].waitForExistence(timeout: 1))
    }
}
