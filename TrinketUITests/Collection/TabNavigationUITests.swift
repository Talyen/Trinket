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
        assertExists("10/10")

        scrollUntilVisible(app.buttons["Weapon item slot"], swipingUp: true)
        assertExists("Weapon item slot")
        assertExists("Armor item slot")
        assertExists("Trinket item slot")
        assertExists("Kindled Ember Wand")
        assertExists("Patient Leather Gloves")
        assertExists("River Charm of Sparks")

        app.buttons["Weapon item slot"].tap()
        assertExists("Equip Weapon")
        assertExists("Equip Kindled Ember Wand")
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
        assertExists("6/6")

        dismissSheet()
        assertExists("Wolf collection card")
        goBack()

        assertExists("Inventory collection category")
        app.buttons["Inventory collection category"].tap()
        assertExists("Kindled Ember Wand item card")
        app.buttons["Kindled Ember Wand item card"].tap()

        assertExists("Kindled Ember Wand")
        assertExists("Warm Focus")
        assertExists("+3% fire-themed ability power.")

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
        assertExists("Inventory collection category")
        app.buttons["Inventory collection category"].tap()
        assertExists("Kindled Ember Wand item card")
        assertExists("Patient Leather Gloves item card")
        assertExists("River Charm of Sparks item card")
        assertExists("Plain Iron Sword item card")
    }

    func testOptionsAndColorSchemeSelection() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        assertExists("Play")
        app.tabBars.buttons["Options"].tap()

        assertExists("Options Screen")
        assertExists("Theme Picker")
        assertExists("Music Volume")
        assertExists("Sound Effects Volume")
        assertExists("Haptics Toggle")

        let themePicker = app.segmentedControls["Theme Picker"]
        themePicker.buttons["Dark"].tap()
        XCTAssertTrue(themePicker.buttons["Dark"].isSelected)
        themePicker.buttons["Light"].tap()
        XCTAssertTrue(themePicker.buttons["Light"].isSelected)
        themePicker.buttons["System"].tap()
        XCTAssertTrue(themePicker.buttons["System"].isSelected)
    }
}
