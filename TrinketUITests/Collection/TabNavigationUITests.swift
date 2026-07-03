import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testHeroDetailEquipmentAndAbilities() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()
        collection.openHeroesCategory()
        assertButtonExists("Knight collection card")
        collection.openCombatantCard(named: "Knight")

        let knightHeader = combatantDetail.header(for: "Knight")
        assertExists(knightHeader)
        XCTAssertEqual(knightHeader.label, "Knight, Hero, level 2, 35 of 120 experience")
        assertCombatantDetailSections()

        scrollUntilVisible(button("Weapon item slot"), swipingUp: true)
        assertButtonExists("Weapon item slot")
        assertButtonExists("Armor item slot")
        assertButtonExists("Trinket item slot")

        button("Weapon item slot").tap()
        assertExists("Equip Weapon")
        XCTAssertTrue(firstEquipOption().waitForExistence(timeout: 5))
        dismissSheet()

        scrollUntilVisible(button("Basic ability slot"), swipingUp: false)
        assertButtonExists("Basic ability slot")
        button("Basic ability slot").tap()
        assertExists("Basic")
        button("Basic Shield Bash ability card").tap()
        assertExists("Shield Bash")

        button("Basic ability slot").tap()
        assertExists("Basic")
        button("Basic Bash ability card").tap()
        assertExists("Bash")

        dismissSheet()
        dismissSheet()

        assertButtonExists("Knight collection card")
        goBack()
    }

    func testPetDetailInspection() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.openPetsCategory()
        assertButtonExists("Wolf collection card")
        assertButtonExists("Bear collection card")
        collection.openCombatantCard(named: "Wolf")

        let wolfHeader = combatantDetail.header(for: "Wolf")
        assertExists(wolfHeader)
        XCTAssertEqual(wolfHeader.label, "Wolf, Pet, level 2, 12 of 100 experience")
        assertCombatantDetailSections()

        dismissSheet()
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
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
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
        assertExists("Inventory filter")
        assertItemCardExists("Crossbow")
        assertItemCardExistsAfterScroll("Wand")
    }

    private func firstEquipOption() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Equip ' AND identifier != 'Equip Weapon'")).firstMatch
    }
}
