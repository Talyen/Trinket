import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testHeroDetailEquipmentAndAbilities() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")

        let knightHeader = combatantDetail.header(for: "Knight")
        assertExists(knightHeader)
        XCTAssertEqual(knightHeader.label, "Knight, Hero, level 2, 35 of 155 experience")
        assertCombatantDetailSections()

        // 1. Abilities section (higher on screen)
        scrollUntilVisible(button("Basic ability slot"), swipingUp: true)
        assertButtonExists("Basic ability slot")
        button("Basic ability slot").tap()
        assertExists("Basic")
        button("Basic Shield Bash ability card").tap()
        assertExists("Shield Bash")

        button("Basic ability slot").tap()
        assertExists("Basic")
        button("Basic Bash ability card").tap()
        assertExists("Bash")

        // 2. Items section (lower on screen)
        scrollUntilVisible(button("Weapon item slot"), swipingUp: true)
        assertButtonExists("Weapon item slot")
        assertButtonExists("Armor item slot")
        assertButtonExists("Trinket item slot")

        button("Weapon item slot").tap()
        assertExists("Equip Weapon")
        XCTAssertTrue(firstEquipOption().waitForExistence(timeout: 2))
        dismissSheet()

        assertButtonExists("Knight collection card")
        goBack()
    }

    func testPetDetailInspection() {
        launchApp(arguments: TestLaunchArg.allForScreen("pet:wolf"))
        combatantDetail.assertLoaded(for: "Wolf")

        let wolfHeader = combatantDetail.header(for: "Wolf")
        assertExists(wolfHeader)
        XCTAssertEqual(wolfHeader.label, "Wolf, Pet, level 2, 12 of 155 experience")
        assertCombatantDetailSections()

        dismissSheet()
        collection.openPetsCategory()
        assertButtonExists("Wolf collection card")
        goBack()
    }

    func testInventoryItemInspection() {
        launchApp(arguments: TestLaunchArg.allForScreen("item:wand-basic"))
        assertExists("Wand")
        assertExists("Affixes")

        goBack()
        collection.assertLoaded()
    }

    func testTabBarRoundTrip() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded(timeout: 2)

        launchApp(arguments: TestLaunchArg.allForTab("options"))
        options.assertLoaded(timeout: 2)

        launchApp(arguments: TestLaunchArg.allForTab("play"))
        play.assertLoaded(timeout: 2)
    }

    func testInventoryGridLayout() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.openInventoryCategory()
        assertExists("Inventory filter")
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
