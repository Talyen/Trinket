import XCTest

final class CoreNavigationUITests: XCTestCase {
    func testCoreTabsAreReachable() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Choose a mode to start building the core loop."].waitForExistence(timeout: 5))

        app.tabBars.buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Paladin"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rogue"].exists)

        app.buttons["Pets"].tap()
        XCTAssertTrue(app.staticTexts["Wolf"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Hawk"].exists)

        app.tabBars.buttons["Inventory"].tap()
        XCTAssertTrue(app.staticTexts["Kindled Ember Wand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Patient Leather Gloves"].exists)

        app.tabBars.buttons["Homestead"].tap()
        XCTAssertTrue(app.staticTexts["A future base for crafting, upgrades, and long-term progression."].waitForExistence(timeout: 5))

        app.tabBars.buttons["Options"].tap()
        XCTAssertTrue(app.staticTexts["Settings, account, accessibility, audio, and credits will live here."].waitForExistence(timeout: 5))

        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Choose a mode to start building the core loop."].waitForExistence(timeout: 5))
    }

    func testCollectionCombatantDetailsAreInspectable() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Paladin"].waitForExistence(timeout: 5))
        app.buttons["Paladin collection card"].tap()
        XCTAssertTrue(app.staticTexts["Health"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10/10 HP"].exists)
        XCTAssertTrue(app.staticTexts["Level 2"].exists)
        XCTAssertTrue(app.staticTexts["35/120 XP"].exists)
        XCTAssertTrue(app.staticTexts["Ability Loadout"].exists)
        XCTAssertTrue(app.staticTexts["Item Loadout"].exists)
        goBack(in: app)

        app.buttons["Pets"].tap()
        XCTAssertTrue(app.staticTexts["Wolf"].waitForExistence(timeout: 5))
        app.buttons["Wolf collection card"].tap()
        XCTAssertTrue(app.staticTexts["Health"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6/6 HP"].exists)
        XCTAssertTrue(app.staticTexts["Level 2"].exists)
        XCTAssertTrue(app.staticTexts["12/100 XP"].exists)
        XCTAssertTrue(app.staticTexts["Ability Loadout"].exists)
        XCTAssertTrue(app.staticTexts["Item Loadout"].exists)
        goBack(in: app)
    }

    func testCollectionAbilityLoadoutChangesBattleAbilities() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Mage"].waitForExistence(timeout: 5))
        app.buttons["Mage collection card"].tap()
        XCTAssertTrue(app.staticTexts["Ability Loadout"].waitForExistence(timeout: 5))
        app.buttons["Mage ability loadout"].tap()
        XCTAssertTrue(app.staticTexts["Abilities"].waitForExistence(timeout: 5))
        app.buttons["Basic Strike ability card"].tap()

        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Battle"].waitForExistence(timeout: 5))
        app.staticTexts["Battle"].tap()

        XCTAssertTrue(app.staticTexts["Select Hero"].waitForExistence(timeout: 5))
        app.staticTexts["Mage"].tap()

        XCTAssertTrue(app.staticTexts["Select Pet"].waitForExistence(timeout: 5))
        app.staticTexts["Drake"].tap()

        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        app.buttons["Battle Log"].tap()
        XCTAssertTrue(app.staticTexts["Mage uses Strike for 1 Physical damage."].waitForExistence(timeout: 5))
    }

    func testInventoryItemDetailsAreInspectable() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Inventory"].tap()
        XCTAssertTrue(app.buttons["Kindled Ember Wand item card"].waitForExistence(timeout: 5))
        app.buttons["Kindled Ember Wand item card"].tap()

        XCTAssertTrue(app.staticTexts["Kindled Ember Wand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ember Wand • Weapon"].exists)
        XCTAssertTrue(app.staticTexts["Warm Focus"].exists)
        XCTAssertTrue(app.staticTexts["+3% fire-themed ability power."].exists)
    }

    func testCollectionItemLoadoutShowsSharedSlots() {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Paladin"].waitForExistence(timeout: 5))
        app.buttons["Paladin collection card"].tap()
        XCTAssertTrue(app.buttons["Paladin item loadout"].waitForExistence(timeout: 5))
        app.buttons["Paladin item loadout"].tap()

        XCTAssertTrue(app.staticTexts["Weapon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Armor"].exists)
        XCTAssertTrue(app.staticTexts["Accessory"].exists)
        XCTAssertTrue(app.staticTexts["Kindled Ember Wand"].exists)
        XCTAssertTrue(app.staticTexts["Patient Leather Gloves"].exists)
        XCTAssertTrue(app.staticTexts["River Charm of Sparks"].exists)
    }

    func testBattleFlowIsReachable() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Battle"].waitForExistence(timeout: 5))
        app.staticTexts["Battle"].tap()

        XCTAssertTrue(app.staticTexts["Select Hero"].waitForExistence(timeout: 5))
        app.staticTexts["Paladin"].tap()

        XCTAssertTrue(app.staticTexts["Select Pet"].waitForExistence(timeout: 5))
        app.staticTexts["Wolf"].tap()

        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Paladin card"].exists)
        XCTAssertTrue(app.buttons["Wolf card"].exists)
        XCTAssertFalse(app.staticTexts["Strike"].waitForExistence(timeout: 1))

        app.buttons["Paladin card"].tap()
        XCTAssertTrue(app.staticTexts["Strike"].waitForExistence(timeout: 5))
        dismissSheet(in: app)

        app.buttons["Battle Log"].tap()
        XCTAssertTrue(app.staticTexts["Paladin and Wolf face Training Slime."].waitForExistence(timeout: 5))
    }

    func testKeywordBattleShowsAbilityDetails() {
        let app = XCUIApplication()
        app.launch()

        startKeywordBattle(in: app)

        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mage card"].exists)
        XCTAssertTrue(app.buttons["Drake card"].exists)
        XCTAssertFalse(app.staticTexts["Ember"].waitForExistence(timeout: 1))

        app.buttons["Mage card"].tap()
        XCTAssertTrue(app.staticTexts["Ember"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 Physical damage. Apply Burn 1 for 2 ticks."].exists)
        dismissSheet(in: app)
    }

    func testKeywordBattleShowsLogAndVictory() {
        let app = XCUIApplication()
        app.launch()

        startKeywordBattle(in: app)

        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mage card"].exists)
        XCTAssertTrue(app.buttons["Drake card"].exists)
        XCTAssertFalse(app.staticTexts["Ember"].exists)

        RunLoop.current.run(until: Date().addingTimeInterval(0.8))

        app.buttons["Battle Log"].tap()
        XCTAssertTrue(app.staticTexts["Mage uses Ember for 1 Physical damage and applies Burn 1 for 2 ticks."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Training Slime takes 2 Burn damage."].exists)
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["Victory"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Experience"].exists)
        XCTAssertTrue(app.staticTexts["Rewards"].exists)
        XCTAssertTrue(app.buttons["Battle Again"].exists)
        XCTAssertFalse(app.buttons["Change Party"].exists)
    }

    func testDebugBattleHarnessStartsPausedAndCanStepToVictory() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-battleDebugHarness",
            "enabled",
            "-battleDebugHero",
            "Mage",
            "-battleDebugPet",
            "Drake"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Battle Debug"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Training Slime card"].exists)
        XCTAssertTrue(app.buttons["Mage card"].exists)
        XCTAssertTrue(app.buttons["Drake card"].exists)
        XCTAssertTrue(app.staticTexts["Debug Tick: 0"].exists)

        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        XCTAssertTrue(app.staticTexts["Debug Tick: 0"].exists)

        app.buttons["Debug Step Tick"].tap()
        XCTAssertTrue(app.staticTexts["Debug Tick: 1"].waitForExistence(timeout: 5))

        app.buttons["Training Slime card"].tap()
        XCTAssertTrue(app.staticTexts["Active Effects"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Burn: 1 damage next tick, 1 stack."].exists)
        dismissSheet(in: app)

        app.buttons["Battle Log"].tap()
        XCTAssertTrue(app.staticTexts["Mage uses Ember for 1 Physical damage and applies Burn 1 for 2 ticks."].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        app.buttons["Debug Finish Battle"].tap()
        XCTAssertTrue(app.staticTexts["Victory"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Experience"].exists)
        XCTAssertTrue(app.staticTexts["Rewards"].exists)
        XCTAssertTrue(app.buttons["Battle Again"].exists)
        XCTAssertFalse(app.buttons["Change Party"].exists)
    }

    private func startKeywordBattle(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["Battle"].waitForExistence(timeout: 5))
        app.staticTexts["Battle"].tap()

        XCTAssertTrue(app.staticTexts["Select Hero"].waitForExistence(timeout: 5))
        app.staticTexts["Mage"].tap()

        XCTAssertTrue(app.staticTexts["Select Pet"].waitForExistence(timeout: 5))
        app.staticTexts["Drake"].tap()
    }

    private func dismissSheet(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }

    private func goBack(in app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
    }
}
