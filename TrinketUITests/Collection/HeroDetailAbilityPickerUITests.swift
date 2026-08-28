import TrinketFeatureSupport
import XCTest

final class HeroDetailAbilityPickerUITests: TrinketUITestCase {
    func testHeroDetailAbilityPickerSelectsAndDismisses() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight", timeout: 8)

        scrollUntilVisible(button(AccessibilityID.Equipment.basicAbilitySlot), swipingUp: true, maxAttempts: 12)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot, timeout: 10)
        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"), timeout: 10)
        button(AccessibilityID.LoadoutPicker.abilityCandidate("block")).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))
        button(AccessibilityID.LoadoutPicker.selectAbility("block")).tap()

        assertDoesNotExist(AccessibilityID.LoadoutPicker.abilityGrid("Basic"), timeout: 5)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)
    }
}
