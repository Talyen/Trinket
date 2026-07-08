import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testHeroDetailEquipmentAndAbilities() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")
        combatantDetail.assertSeededHeroHeaderSummary(for: "Knight")
        assertCombatantDetailSections()

        // 1. Abilities section (higher on screen)
        scrollUntilVisible(button(AccessibilityID.Equipment.basicAbilitySlot), swipingUp: true)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)
        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists("Basic")
        button("Basic Shield Bash ability card").tap()
        assertExists("Shield Bash")

        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists("Basic")
        button("Basic Bash ability card").tap()
        assertExists("Bash")

        // 2. Items section (lower on screen)
        scrollUntilVisible(button(AccessibilityID.Equipment.weaponSlot), swipingUp: true)
        assertButtonExists(AccessibilityID.Equipment.weaponSlot)
        assertButtonExists(AccessibilityID.Equipment.armorSlot)
        assertButtonExists(AccessibilityID.Equipment.trinketSlot)

        button(AccessibilityID.Equipment.weaponSlot).tap()
        assertExists(AccessibilityID.Equipment.equipWeapon)
        XCTAssertTrue(firstEquipOption().waitForExistence(timeout: 2))
        dismissSheet()

        assertButtonExists(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        goBack()
    }

    func testFreshStartItemSlotsRenderLockedUntilSlotItemExists() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync
        ] + TestLaunchArg.screen("hero:knight"))

        scrollUntilVisible(app.descendants(matching: .any)[AccessibilityID.Equipment.weaponSlot], swipingUp: true)
        assertExists(AccessibilityID.Equipment.findWeaponToUnlock)
        assertExists(AccessibilityID.Equipment.findArmorToUnlock)
        assertExists(AccessibilityID.Equipment.findTrinketToUnlock)

        app.descendants(matching: .any)[AccessibilityID.Equipment.weaponSlot].tap()
        XCTAssertFalse(app.navigationBars[AccessibilityID.Equipment.equipWeapon].waitForExistence(timeout: 1))
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

    func testInventoryGridLayout() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.openInventoryCategory()
        assertExists(AccessibilityID.Collection.inventoryFilter)
        assertItemCardExists("Crossbow")
        collection.filterInventory(to: "Weapon")
        assertItemCardExists("Crossbow")
        collection.filterInventory(to: "All")
        assertItemCardExists("Crossbow")
    }

    func testCollectionScreenAccessibility() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.petsCategory)
        assertExists(AccessibilityID.Collection.inventoryCategory)
        assertAccessibilityAudit()
    }

    private func firstEquipOption() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Equip ' AND identifier != 'Equip Weapon'")).firstMatch
    }
}
