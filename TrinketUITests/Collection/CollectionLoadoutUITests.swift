import TrinketCore
import TrinketFeatureSupport
import XCTest

final class CollectionLoadoutUITests: TrinketUITestCase {
    func testEquippedWeaponRemainsEquippedAfterRelaunch() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        openWeaponPicker()
        let candidate = AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral")
        assertExistsAfterScroll(candidate, requireHittable: true)
        tapButton(candidate)
        tapButton(AccessibilityID.LoadoutPicker.equipItem("longsword-astral"))
        assertDoesNotExist(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
        relaunchApp(arguments: TestLaunchArg.screen("hero:knight"))
        openWeaponPicker()
        assertExistsAfterScroll(candidate, requireHittable: true)
        tapButton(candidate)
        assertExists(AccessibilityID.LoadoutPicker.unequipItem)
        assertDoesNotExist(AccessibilityID.LoadoutPicker.equipItem("longsword-astral"))
    }

    private func openWeaponPicker() {
        combatantDetail.assertLoaded(for: "Knight")
        let slot = ItemSlot.weapon.accessibilityIdentifier
        assertExistsAfterScroll(slot, requireHittable: true)
        tapButton(slot)
        assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
        let search = app.searchFields.firstMatch
        replaceText(in: search, with: "longsword")
        search.typeText("\n")
    }
}
