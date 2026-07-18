import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    /// Equip one ability; persistence is visible on the slot label.
    func testHeroDetailEquipmentAndAbilities() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")

        scrollUntilVisible(button(AccessibilityID.Equipment.basicAbilitySlot), swipingUp: true)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)
        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"))
        button(AccessibilityID.LoadoutPicker.abilityCandidate("block")).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))
        button(AccessibilityID.LoadoutPicker.selectAbility("block")).tap()

        let basicSlot = button(AccessibilityID.Equipment.basicAbilitySlot)
        assertExists(basicSlot)
        XCTAssertTrue(
            basicSlot.label.localizedCaseInsensitiveContains("Block"),
            "Equipped Basic ability name should remain visible on the slot label"
        )
    }

    func testTabBarRoundTrip() {
        // One launch + real tab bar navigation (not three deep-link relaunches).
        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.assertLoaded()

        tabBar.selectHomestead()
        homestead.assertLoaded()

        tabBar.selectOptions()
        options.assertLoaded()

        tabBar.selectPlay()
        play.assertLoaded()
    }
}
