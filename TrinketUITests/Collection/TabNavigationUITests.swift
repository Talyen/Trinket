import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testTabNavigationAndInspectionFlow() {
        launchApp(arguments: [TestLaunchArg.resetState])

        assertExists("Play")

        app.tabBars.buttons["Collection"].tap()
        assertExists("Heroes collection category")
        app.buttons["Heroes collection category"].tap()
        assertExists("Paladin collection card")
        app.buttons["Paladin collection card"].tap()

        assertExists("Paladin detail hero header")
        assertExists("Level 2")
        assertExists("35/120 XP")
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
        app.buttons["Basic Shield Jab ability card"].tap()
        assertExists("Shield Jab")

        app.buttons["Basic ability slot"].tap()
        assertExists("Basic")
        app.buttons["Basic Strike ability card"].tap()
        assertExists("Strike")

        goBack()
        assertExists("Paladin collection card")
        goBack()

        assertExists("Pets collection category")
        app.buttons["Pets collection category"].tap()
        assertExists("Wolf collection card")
        assertExists("Hawk collection card")
        app.buttons["Wolf collection card"].tap()

        assertExists("Wolf detail hero header")
        assertExists("Level 2")
        assertExists("12/100 XP")
        assertExists("Stats")
        assertExists("Health")
        assertExists("6/6")

        goBack()
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

        app.tabBars.buttons["Play"].tap()
        assertExists("Play")
    }

    func testInventoryGridLayout() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Collection"].tap()
        assertExists("Inventory collection category")
        app.buttons["Inventory collection category"].tap()
        assertExists("Kindled Ember Wand item card")
        assertExists("Patient Leather Gloves item card")
        assertExists("River Charm of Sparks item card")
        assertExists("Plain Iron Sword item card")
    }

    func testOptionsAndColorSchemeSelection() {
        launchApp(arguments: [
            TestLaunchArg.resetState
        ])

        assertExists("Play")
        app.buttons.containing(.staticText, identifier: "Battle").firstMatch.tap()
        assertExists("Paladin selection card")
        app.buttons["Paladin selection card"].tap()
        assertExists("Wolf selection card")
        app.buttons["Wolf selection card"].tap()

        assertExists("Battle Pause Button")
        app.buttons["Battle Pause Button"].tap()

        app.buttons["Battle Menu"].tap()
        assertExists("Options menu item")
        app.buttons["Options menu item"].tap()

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

        app.buttons["Done"].tap()
    }
}
