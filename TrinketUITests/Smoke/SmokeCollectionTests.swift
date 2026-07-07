import XCTest

final class SmokeCollectionTests: TrinketUITestCase {
    func testCollectionScreenLoads() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        assertExists("Heroes collection category")
        assertExists("Pets collection category")
        assertExists(AccessibilityID.Collection.inventoryCategory)
        assertAccessibilityAudit()
    }
}
