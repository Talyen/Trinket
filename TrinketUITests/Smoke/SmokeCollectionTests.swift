import XCTest

final class SmokeCollectionTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-selectedTab",
            "collection"
        ]
    }

    func testFreshStartCollectionHidesInventorySection() {
        collection.assertLoaded()
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.companionsCategory)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryCategory].exists)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryEmptyState].exists)
    }
}
