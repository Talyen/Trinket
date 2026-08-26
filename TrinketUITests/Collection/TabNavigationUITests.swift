import TrinketFeatureSupport
import XCTest

/// Collection shelf and inventory-grid salvage. One launch covers both surfaces.
final class TabNavigationUITests: TrinketUITestCase {
    func testSalvageRemovesShelfAndInventoryGridItemsImmediately() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()

        assertSalvageRemovesItemImmediately(
            itemID: "crossbow-basic",
            remainingItemID: "crossbow-astral"
        )

        tapButton(AccessibilityID.Collection.inventoryCategory)
        assertSalvageRemovesItemImmediately(
            itemID: "mace-basic",
            remainingItemID: "mace-astral"
        )
    }

    private func assertSalvageRemovesItemImmediately(
        itemID: String,
        remainingItemID: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let salvagedItemID = AccessibilityID.Collection.itemCard(itemID: itemID)
        let remainingCardID = AccessibilityID.Collection.itemCard(itemID: remainingItemID)
        let salvagedItem = app.buttons[salvagedItemID]
        scrollUntilVisible(salvagedItem, swipingUp: false, requireHittable: true)
        if !salvagedItem.exists || !salvagedItem.isHittable {
            scrollUntilVisible(salvagedItem, swipingUp: true, requireHittable: true)
        }

        salvagedItem.tap()
        scrollUntilVisible(button(AccessibilityID.Collection.salvageButton), swipingUp: true)
        tapButton(AccessibilityID.Collection.salvageButton)
        app.alerts.buttons["Salvage"].firstMatch.tap()

        assertDoesNotExist(salvagedItemID, timeout: 5, file: file, line: line)
        assertExistsAfterScroll(remainingCardID, file: file, line: line)
    }
}
