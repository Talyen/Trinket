import TrinketFeatureSupport
import XCTest

/// Tab-reachable surface journeys that smoke does not own: loadout picker and Homestead detail.
final class TabNavigationUITests: TrinketUITestCase {
    func testSalvageRemovesCollectionShelfItemImmediately() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()

        assertSalvageRemovesCrossbowImmediately()
    }

    func testSalvageRemovesInventoryGridItemImmediately() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()
        tapButton(AccessibilityID.Collection.inventoryCategory)

        assertSalvageRemovesCrossbowImmediately()
    }

    func testHeroDetailAbilityPickerSelectsAndDismisses() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight", timeout: 8)

        scrollUntilVisible(button(AccessibilityID.Equipment.basicAbilitySlot), swipingUp: true)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)
        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"))
        button(AccessibilityID.LoadoutPicker.abilityCandidate("block")).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))
        button(AccessibilityID.LoadoutPicker.selectAbility("block")).tap()

        assertDoesNotExist(AccessibilityID.LoadoutPicker.abilityGrid("Basic"), timeout: 5)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)
    }

    /// Homestead category → node → detail navigation is usable (CI-owned owner;
    /// perf harness only exercises this as a side effect).
    func testHomesteadNodeDetailJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()

        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        homestead.assertNodeDetail(named: "Wheat Field")
    }

    private func assertSalvageRemovesCrossbowImmediately(
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let salvagedItemID = AccessibilityID.Collection.itemCard(itemID: "crossbow-basic")
        let remainingItemID = AccessibilityID.Collection.itemCard(itemID: "crossbow-astral")
        let salvagedItem = app.buttons[salvagedItemID]
        scrollUntilVisible(salvagedItem, swipingUp: true, requireHittable: true)

        salvagedItem.tap()
        scrollUntilVisible(button(AccessibilityID.Collection.salvageButton), swipingUp: true)
        tapButton(AccessibilityID.Collection.salvageButton)
        app.alerts.buttons["Salvage"].firstMatch.tap()

        assertDoesNotExist(salvagedItemID, timeout: 5, file: file, line: line)
        assertExistsAfterScroll(remainingItemID, file: file, line: line)
    }
}
