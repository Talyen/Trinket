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
        XCTAssertTrue(
            app.navigationBars["Basic"].waitForExistence(timeout: Self.defaultTimeout),
            "Basic ability picker not found"
        )
        button("Basic Bash ability card").tap()
        assertExists("Bash")

        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        XCTAssertTrue(
            app.navigationBars["Basic"].waitForExistence(timeout: Self.defaultTimeout),
            "Basic ability picker not found"
        )
        button("Basic Block ability card").tap()
        assertExists("Block")

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

        let weaponSlot = app.descendants(matching: .any)[AccessibilityID.Equipment.weaponSlot]
        let armorSlot = app.descendants(matching: .any)[AccessibilityID.Equipment.armorSlot]
        let trinketSlot = app.descendants(matching: .any)[AccessibilityID.Equipment.trinketSlot]
        scrollUntilVisible(weaponSlot, swipingUp: true)

        // Locked slots combine into a single element; the unlock instructions now live
        // in that element's accessibility label rather than as a standalone element.
        XCTAssertTrue(weaponSlot.waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertTrue(weaponSlot.label.contains(AccessibilityID.Equipment.findWeaponToUnlock))
        XCTAssertTrue(armorSlot.label.contains(AccessibilityID.Equipment.findArmorToUnlock))
        XCTAssertTrue(trinketSlot.label.contains(AccessibilityID.Equipment.findTrinketToUnlock))

        weaponSlot.tap()
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

    private func firstEquipOption() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Equip ' AND identifier != 'Equip Weapon'")).firstMatch
    }
}
