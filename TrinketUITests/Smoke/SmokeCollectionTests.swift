import XCTest

final class SmokeCollectionTests: TrinketUITestCase {
    func testCollectionScreenAndHeroesGrid() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        assertExists("Heroes collection category")
        assertExists("Pets collection category")
        assertExists(AccessibilityID.Collection.inventoryCategory)

        app.buttons["Heroes collection category"].tap()
        assertExists("Knight collection card")
        assertExists("Wizard collection card")
        assertExists("Rogue collection card")
    }

    func testFreshStartCollectionShowsInventoryEmptyState() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-selectedTab",
            "collection"
        ])
        assertExists("Heroes collection category")
        assertExists("Pets collection category")
        assertExists(AccessibilityID.Collection.inventoryCategory)
        assertExists(AccessibilityID.Collection.inventoryEmptyState)
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
