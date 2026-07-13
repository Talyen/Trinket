import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testHeroDetailEquipmentAndAbilities() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")
        assertCombatantDetailSections()

        // 1. Abilities section (higher on screen)
        scrollUntilVisible(button(AccessibilityID.Equipment.basicAbilitySlot), swipingUp: true)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)
        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        XCTAssertTrue(
            app.navigationBars["Basic"].waitForExistence(timeout: Self.defaultTimeout),
            "Basic ability picker not found"
        )
        assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"))
        button(AccessibilityID.LoadoutPicker.abilityCandidate("block")).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))
        button(AccessibilityID.LoadoutPicker.selectAbility("block")).tap()
        assertExists("Block")

        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityCandidate("block"))
        goBack()

        // 2. Items section (lower on screen)
        scrollUntilVisible(button(AccessibilityID.Equipment.weaponSlot), swipingUp: true)
        assertButtonExists(AccessibilityID.Equipment.weaponSlot)
        assertButtonExists(AccessibilityID.Equipment.armorSlot)
        assertButtonExists(AccessibilityID.Equipment.trinketSlot)

        button(AccessibilityID.Equipment.weaponSlot).tap()
        assertExists(AccessibilityID.Equipment.equipWeapon)
        assertExists(AccessibilityID.LoadoutPicker.itemGrid("Weapon"))
        button(AccessibilityID.LoadoutPicker.itemCandidate("crossbow-basic")).tap()
        assertExists(AccessibilityID.LoadoutPicker.itemDetail("crossbow-basic"))
        button(AccessibilityID.LoadoutPicker.equipItem("crossbow-basic")).tap()

        button(AccessibilityID.Equipment.weaponSlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.itemCandidate("crossbow-basic"))
        goBack()
        dismissSheet()

        assertButtonExists(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        goBack()
    }

    func testFreshStartItemSlotsRenderLockedUntilSlotItemExists() {
        launchApp(arguments: [
            TestLaunchArg.resetState,
            TestLaunchArg.disableCloudSync
        ] + TestLaunchArg.screen("hero:knight"))

        let weaponSlot = app.staticTexts[AccessibilityID.Equipment.weaponSlot]
        let armorSlot = app.descendants(matching: .any)[AccessibilityID.Equipment.armorSlot]
        let trinketSlot = app.descendants(matching: .any)[AccessibilityID.Equipment.trinketSlot]
        scrollUntilVisible(weaponSlot, swipingUp: true)

        // Locked slots remain visible and inert until a matching item exists.
        XCTAssertTrue(weaponSlot.waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertTrue(app.staticTexts["Weapon"].waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertTrue(app.staticTexts["Armor"].waitForExistence(timeout: Self.defaultTimeout))
        XCTAssertTrue(app.staticTexts["Trinket"].waitForExistence(timeout: Self.defaultTimeout))

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
}
