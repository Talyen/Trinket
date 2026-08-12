import TrinketFeatureSupport
import XCTest

final class SmokeCollectionTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-disable-audio",
            "-persist-save-immediately",
            "-selectedTab",
            "collection",
        ]
    }

    func testFreshStartCollectionHidesInventorySection() {
        // Cold launch onto Collection under smoke-full can exceed the 3s deep-link default.
        collection.assertLoaded(timeout: 8)
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.companionsCategory)
        // The inventory negatives are only meaningful once the shell content has
        // rendered; a known hero shelf card is the stable post-scroll marker.
        assertExistsAfterScroll(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryCategory].exists)
        XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.Collection.inventoryEmptyState].exists)
    }
}
