import TrinketCore
import TrinketFeatureSupport
import XCTest

final class CollectionLoadoutUITests: TrinketUITestCase {
    func testWeaponPickerEquipsAndUnequipsAnOwnedWeapon() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight") + ["-equipment-picker-fixture"])
        openWeaponPicker()
        let candidate = AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral")
        assertExistsAfterScroll(candidate, requireHittable: true)
        tapButton(candidate)
        tapButton(AccessibilityID.LoadoutPicker.equipItem("longsword-astral"))
        assertDoesNotExist(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
        openWeaponPicker()
        assertExistsAfterScroll(candidate, requireHittable: true)
        tapButton(candidate)
        tapButton(AccessibilityID.LoadoutPicker.unequipItem)
        assertDoesNotExist(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
        openWeaponPicker()
        assertExistsAfterScroll(candidate, requireHittable: true)
        tapButton(candidate)
        assertExists(AccessibilityID.LoadoutPicker.equipItem("longsword-astral"))
        assertDoesNotExist(AccessibilityID.LoadoutPicker.unequipItem)
    }

    private func openWeaponPicker() {
        combatantDetail.assertLoaded(for: "Knight")
        let slot = ItemSlot.weapon.accessibilityIdentifier
        assertExistsAfterScroll(slot, requireHittable: true)
        tapButton(slot)
        assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
    }
}
