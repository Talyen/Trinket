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
        // Cold launch onto Collection under smoke-full can exceed the 3s deep-link default.
        collection.assertLoaded(timeout: 8)
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.companionsCategory)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryCategory].exists)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryEmptyState].exists)
    }
}
