import XCTest

final class SmokeCollectionTests: TrinketUITestCase {
    func testCollectionScreenLoads() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()
        assertExists(AccessibilityID.Collection.petsCategory)
        assertExists(AccessibilityID.Collection.inventoryCategory)
        assertExists(collection.searchField)
    }

    func testFreshStartCollectionHidesInventorySection() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-selectedTab",
            "collection"
        ])
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.petsCategory)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryCategory].exists)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryEmptyState].exists)
    }
}
