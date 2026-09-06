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

        scrollUntilVisible(button(AccessibilityID.Collection.basicGearCategory), swipingUp: false, requireHittable: true)
        assertExistsAfterScroll(AccessibilityID.Collection.basicGearCategory, requireHittable: true)
        tapButton(AccessibilityID.Collection.basicGearCategory)
        assertDoesNotExist(AccessibilityID.Collection.itemCard(itemID: "crossbow-astral"))
        assertSalvageRemovesItemImmediately(
            itemID: "dagger-basic",
            remainingItemID: "double_axe-basic",
        )

        tapButton(AccessibilityID.Collection.gearFilter)
        tapButton(AccessibilityID.Collection.gearFilterOption(slot: "armor"))
        assertExists(AccessibilityID.Collection.itemCard(itemID: "leather_armor-basic"))
        assertDoesNotExist(AccessibilityID.Collection.itemCard(itemID: "double_axe-basic"))
        assertDoesNotExist(AccessibilityID.Collection.itemCard(itemID: "leather_armor-astral"))

        assertSalvageRemovesItemImmediately(
            itemID: "leather_armor-basic",
            remainingItemID: "plate_armor-basic",
        )
        salvageItem(itemID: "plate_armor-basic")
        assertExists(AccessibilityID.Collection.itemsNoResults)
        assertDoesNotExist(AccessibilityID.Collection.itemsEmptyState)

        tapButton(AccessibilityID.Collection.gearFilter)
        tapButton(AccessibilityID.Collection.gearFilterOption(slot: "all"))
        assertExistsAfterScroll(AccessibilityID.Collection.itemCard(itemID: "double_axe-basic"))
        goBack()
        assertExistsAfterScroll(AccessibilityID.Collection.astralGearCategory, requireHittable: true)
        tapButton(AccessibilityID.Collection.astralGearCategory)
        assertExists(AccessibilityID.Collection.itemCard(itemID: "crossbow-astral"))
        assertDoesNotExist(AccessibilityID.Collection.itemCard(itemID: "double_axe-basic"))
    }

    private func assertSalvageRemovesItemImmediately(
        itemID: String,
        remainingItemID: String,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        salvageItem(itemID: itemID, file: file, line: line)
        assertExistsAfterScroll(
            AccessibilityID.Collection.itemCard(itemID: remainingItemID),
            maxAttempts: 12,
            file: file,
            line: line,
        )
    }

    private func salvageItem(
        itemID: String,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let salvagedItemID = AccessibilityID.Collection.itemCard(itemID: itemID)
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
    }
}
