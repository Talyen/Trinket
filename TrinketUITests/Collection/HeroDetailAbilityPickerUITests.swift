import TrinketCore
import TrinketFeatureSupport
import XCTest

final class HeroDetailAbilityPickerUITests: TrinketUITestCase {
    @MainActor
    func testHeroDetailAbilitySelectAndDismiss() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight", timeout: 8)

        scrollUntilVisible(
            button(AccessibilityID.Equipment.basicAbilitySlot),
            swipingUp: true,
            maxAttempts: 6,
            requireHittable: true,
        )
        tapButton(AccessibilityID.Equipment.basicAbilitySlot)
        assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"), timeout: 10)
        tapButton(AccessibilityID.LoadoutPicker.abilityCandidate("block"))
        assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))
        tapButton(AccessibilityID.LoadoutPicker.selectAbility("block"))

        assertDoesNotExist(AccessibilityID.LoadoutPicker.abilityGrid("Basic"), timeout: 5)
        tapButton(AccessibilityID.Equipment.basicAbilitySlot)
        let selectedAbility = button(AccessibilityID.LoadoutPicker.abilityCandidate("block"))
        assertExists(selectedAbility)
        XCTAssertTrue(selectedAbility.isSelected, "Block must remain equipped after the picker closes")
    }

    @MainActor
    func testHeroDetailItemSearchEquipAndDismiss() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight", timeout: 8)

        let weaponSlot = ItemSlot.weapon.accessibilityIdentifier
        scrollUntilVisible(button(weaponSlot), swipingUp: true, maxAttempts: 6, requireHittable: true)
        tapButton(weaponSlot)
        assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"), timeout: 10)
        app.scrollViews[AccessibilityID.LoadoutPicker.itemGrid("Weapon")].swipeUp()
        tapButton(AccessibilityID.LoadoutPicker.itemFilter)
        tapButton(AccessibilityID.LoadoutPicker.itemRarityFilter)
        // The rarity menu exposes options by label only; "Astral" is the product contract here.
        tapButton("Astral")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.trinketWaitForExistence(timeout: 5))
        replaceText(in: search, with: "no-such-equipment")
        assertExists(AccessibilityID.LoadoutPicker.itemsNoResults)
        replaceText(in: search, with: "long")
        let candidateID = AccessibilityID.LoadoutPicker.itemCandidate("longsword-astral")
        tapButton(candidateID)
        assertExists(AccessibilityID.LoadoutPicker.itemDetail("longsword-astral"))
        goBack()
        assertButtonExists(candidateID)
        XCTAssertEqual(search.value as? String, "long")
        tapButton(candidateID)
        tapButton(AccessibilityID.LoadoutPicker.equipItem("longsword-astral"))
        assertDoesNotExist(AccessibilityID.LoadoutPicker.itemGrid("Weapon"), timeout: 5)
        tapButton(weaponSlot)
        replaceText(in: app.searchFields.firstMatch, with: "long")
        let equippedItem = button(candidateID)
        assertExists(equippedItem)
        XCTAssertTrue(equippedItem.isSelected, "The longsword must remain equipped after the picker closes")
    }
}
