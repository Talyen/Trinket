import TrinketCore
import TrinketFeatureSupport
import XCTest

final class HeroDetailAbilityPickerUITests: TrinketUITestCase {
    @MainActor
    func testHeroDetailPickersSelectAndDismiss() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight", timeout: 8)

        scrollUntilVisible(button(AccessibilityID.Equipment.basicAbilitySlot), swipingUp: true, maxAttempts: 12)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot, timeout: 10)
        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"), timeout: 10)
        for abilityID in ["bash", "block", "shield-bash", "slash"] {
            assertButtonExists(AccessibilityID.LoadoutPicker.abilityCandidate(abilityID), timeout: 5)
        }
        button(AccessibilityID.LoadoutPicker.abilityCandidate("block")).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))
        button(AccessibilityID.LoadoutPicker.selectAbility("block")).tap()

        assertDoesNotExist(AccessibilityID.LoadoutPicker.abilityGrid("Basic"), timeout: 5)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)

        let weaponSlot = ItemSlot.weapon.accessibilityIdentifier
        scrollUntilVisible(button(weaponSlot), swipingUp: true, maxAttempts: 12)
        button(weaponSlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"), timeout: 10)
        assertButtonExists(AccessibilityID.LoadoutPicker.itemFilter)
        button(AccessibilityID.LoadoutPicker.itemFilter).tap()
        button(AccessibilityID.LoadoutPicker.itemRarityFilter).tap()
        app.buttons["Astral"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.trinketWaitForExistence(timeout: 5))
        replaceText(in: search, with: "no-matching-equipment")
        assertExists(AccessibilityID.LoadoutPicker.itemsNoResults)
        button(AccessibilityID.LoadoutPicker.clearItemFilters).tap()
        replaceText(in: search, with: "longsword")
        app.buttons["close"].tap()
        goBack()
        button(weaponSlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"), timeout: 10)
        XCTAssertNotEqual(search.value as? String, "longsword")
        replaceText(in: search, with: "longsword")
        let candidateID = AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral")
        assertButtonExists(candidateID)
        button(candidateID).tap()
        assertExists(AccessibilityID.LoadoutPicker.itemDetail("longsword-astral"))
        goBack()
        assertButtonExists(candidateID)
        XCTAssertEqual(search.value as? String, "longsword")
        button(candidateID).tap()
        button(AccessibilityID.LoadoutPicker.equipItem("longsword-astral")).tap()
        assertDoesNotExist(AccessibilityID.LoadoutPicker.itemGrid("Weapon"), timeout: 5)
        assertButtonExists(weaponSlot)
    }
}
