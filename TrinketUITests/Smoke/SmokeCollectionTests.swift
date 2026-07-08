import XCTest

final class SmokeCollectionTests: TrinketUITestCase {
    func testCollectionScreenLoads() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()
        assertExists(AccessibilityID.Collection.petsCategory)
        assertExists(AccessibilityID.Collection.inventoryCategory)
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

    func testFreshStartCollectionHasNoNewMarkersOnStarters() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync,
            "-selectedTab",
            "collection"
        ])
        collection.assertLoaded()

        let knight = button(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        let bear = button(AccessibilityID.CombatantDetail.collectionCard(name: "Bear"))
        XCTAssertTrue(knight.waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertTrue(bear.waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertFalse(
            knight.label.localizedCaseInsensitiveContains("new"),
            "Starter Knight should not show NEW attention: \(knight.label)"
        )
        XCTAssertFalse(
            bear.label.localizedCaseInsensitiveContains("new"),
            "Starter Bear should not show NEW attention: \(bear.label)"
        )
    }
}
