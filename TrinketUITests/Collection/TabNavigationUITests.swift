import TrinketFeatureSupport
import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testSalvageRemovesShelfAndInventoryGridItemsImmediately() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()

        assertSalvageRemovesItemImmediately(
            itemID: "crossbow-basic",
            remainingItemID: "crossbow-astral",
        )

        tapButton(AccessibilityID.Collection.inventoryCategory)
        assertSalvageRemovesItemImmediately(
            itemID: "mace-basic",
            remainingItemID: "mace-astral",
        )
    }

    private func assertSalvageRemovesItemImmediately(
        itemID: String,
        remainingItemID: String,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let salvagedItemID = AccessibilityID.Collection.itemCard(itemID: itemID)
        let remainingCardID = AccessibilityID.Collection.itemCard(itemID: remainingItemID)
        let salvagedItem = app.buttons[salvagedItemID]
        scrollUntilVisible(salvagedItem, swipingUp: false, maxAttempts: 12, requireHittable: true)
        if !salvagedItem.exists || !salvagedItem.isHittable {
            scrollUntilVisible(salvagedItem, swipingUp: true, maxAttempts: 12, requireHittable: true)
        }

        salvagedItem.tap()
        scrollUntilVisible(button(AccessibilityID.Collection.salvageButton), swipingUp: true, maxAttempts: 12)
        tapButton(AccessibilityID.Collection.salvageButton, timeout: 10)
        app.alerts.buttons["Salvage"].firstMatch.tap()

        assertDoesNotExist(salvagedItemID, timeout: 10, file: file, line: line)
        assertExistsAfterScroll(remainingCardID, maxAttempts: 12, file: file, line: line)
    }
}
