import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testTabNavigationAndInspectionFlow() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        assertExists("Play")

        app.tabBars.buttons["Collection"].tap()
        assertExists("Heroes collection category")
        app.buttons["Heroes collection category"].tap()
        assertExists("Knight collection card")
        app.buttons["Knight collection card"].tap()

        let knightHeader = app.descendants(matching: .any)["Knight detail hero header"]
        assertExists(knightHeader)
        XCTAssertEqual(knightHeader.label, "Knight, Hero, level 2, 35 of 120 experience")
        assertExists("Stats")
        assertExists("Health")

        scrollUntilVisible(app.buttons["Weapon item slot"], swipingUp: true)
        assertExists("Weapon item slot")
        assertExists("Armor item slot")
        assertExists("Trinket item slot")

        app.buttons["Weapon item slot"].tap()
        assertExists("Equip Weapon")
        XCTAssertTrue(firstEquipOption().waitForExistence(timeout: 5))
        dismissSheet()

        scrollUntilVisible(app.buttons["Basic ability slot"], swipingUp: false)
        assertExists("Basic ability slot")
        app.buttons["Basic ability slot"].tap()
        assertExists("Basic")
        app.buttons["Basic Shield Bash ability card"].tap()
        assertExists("Shield Bash")

        app.buttons["Basic ability slot"].tap()
        assertExists("Basic")
        app.buttons["Basic Bash ability card"].tap()
        assertExists("Bash")

        dismissSheet()
        dismissSheet()

        assertExists("Knight collection card")
        goBack()

        assertExists("Pets collection category")
        app.buttons["Pets collection category"].tap()
        assertExists("Wolf collection card")
        assertExists("Bear collection card")
        app.buttons["Wolf collection card"].tap()

        let wolfHeader = app.descendants(matching: .any)["Wolf detail hero header"]
        assertExists(wolfHeader)
        XCTAssertEqual(wolfHeader.label, "Wolf, Pet, level 2, 12 of 100 experience")
        assertExists("Stats")
        assertExists("Health")

        dismissSheet()
        assertExists("Wolf collection card")
        goBack()

        assertExists("Inventory collection category")
        app.buttons["Inventory collection category"].tap()
        assertItemCardExistsAfterScroll("Wand", maxAttempts: 24)
        app.buttons.matching(identifier: "Wand item card").firstMatch.tap()

        assertExists("Wand")
        assertExists("Affixes")

        goBack()
        goBack()

        app.tabBars.buttons["Homestead"].tap()
        assertExists("Homestead")

        app.tabBars.buttons["Options"].tap()
        assertExists("Options Screen")

        app.tabBars.buttons["Play"].tap()
        assertExists("Play")
    }

    func testInventoryGridLayout() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.tabBars.buttons["Collection"].tap()
        app.buttons["Inventory collection category"].tap()
        assertExists("Inventory filter")
        assertItemCardExists("Crossbow")
        assertItemCardExistsAfterScroll("Wand", maxAttempts: 24)
    }

    private func firstEquipOption() -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'Equip ' AND identifier != 'Equip Weapon'")).firstMatch
    }
}
