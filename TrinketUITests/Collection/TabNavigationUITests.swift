import TrinketFeatureSupport
import XCTest

/// Tab-reachable surface journeys: the shared tab bar plus Collection, Homestead,
/// and Options interactions that ship through the tab shell.
final class TabNavigationUITests: TrinketUITestCase {
    /// Equip one ability; persistence is visible on the slot label.
    func testHeroDetailEquipmentAndAbilities() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight", timeout: 8)

        scrollUntilVisible(button(AccessibilityID.Equipment.basicAbilitySlot), swipingUp: true)
        assertButtonExists(AccessibilityID.Equipment.basicAbilitySlot)
        button(AccessibilityID.Equipment.basicAbilitySlot).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityGrid("Basic"))
        button(AccessibilityID.LoadoutPicker.abilityCandidate("block")).tap()
        assertExists(AccessibilityID.LoadoutPicker.abilityDetail("block"))

        // Back from a candidate detail should return to the tier grid, not the hero detail.
        goBack()
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

    /// Seeded inventory populates the Collection shelf; the browse grid and its
    /// slot filter are reachable (positive counterpart to SmokeCollectionTests).
    func testInventoryBrowseAndFilter() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()

        assertExistsAfterScroll(
            AccessibilityID.Collection.inventoryCategory,
            requireHittable: true
        )
        collection.openInventoryCategory()

        assertExists(AccessibilityID.Collection.inventoryFilter)
        let itemCard = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier ENDSWITH %@", " item card")
        ).firstMatch
        XCTAssertTrue(
            itemCard.waitForExistence(timeout: Self.defaultTimeout),
            "Seeded inventory should list item cards"
        )

        collection.filterInventory(to: "Weapon")
        XCTAssertTrue(
            itemCard.waitForExistence(timeout: Self.defaultTimeout),
            "Weapon filter should keep item cards visible"
        )
        assertDoesNotExist(AccessibilityID.Collection.inventoryNoResults, timeout: 2)
    }

    /// Options settings controls are interactive; tapping a toggle flips its state.
    func testOptionsToggleFlipsVisibleState() {
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        options.assertLoaded()

        let toggle = app.descendants(matching: .any)[
            "Remember Auto-Battle Preference Toggle"
        ]
        XCTAssertTrue(
            toggle.waitForExistence(timeout: Self.defaultTimeout),
            "Auto-battle preference toggle not found"
        )
        let initialValue = toggle.value as? String
        // Toggle knob sits at the row's trailing edge; tap it, not the row label.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        let deadline = Date().addingTimeInterval(3)
        while (toggle.value as? String) == initialValue, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertNotEqual(
            toggle.value as? String,
            initialValue,
            "Toggle value should flip when tapped"
        )
    }

    /// Homestead category → node → detail navigation is usable (CI-owned owner;
    /// perf harness only exercises this as a side effect).
    func testHomesteadNodeDetailJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()

        tapButton(AccessibilityID.Homestead.category("Farming"))
        // Category push can leave Wheat Field below the fold; give navigation a
        // beat before the scroll hunt so we do not swipe the overview.
        _ = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")]
            .waitForExistence(timeout: 2)
        assertExistsAfterScroll(
            AccessibilityID.Homestead.node(title: "Wheat Field"),
            maxAttempts: 10
        )
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        homestead.assertNodeDetail(named: "Wheat Field")
        assertExists(AccessibilityID.Homestead.tierPath)
    }
}
