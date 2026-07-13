import XCTest

final class SmokeCollectionTests: TrinketUITestCase {
    func testFreshStartCollectionHidesInventorySection() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-selectedTab",
            "collection"
        ])
        collection.assertLoaded()
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.companionsCategory)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryCategory].exists)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryEmptyState].exists)
    }
}
