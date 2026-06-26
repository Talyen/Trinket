import XCTest

final class CoreNavigationUITests: XCTestCase {
    func testCoreTabsAreReachable() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Choose a mode to start building the core loop."].waitForExistence(timeout: 5))

        app.tabBars.buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Paladin"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Rogue"].exists)

        app.tabBars.buttons["Pets"].tap()
        XCTAssertTrue(app.staticTexts["Wolf"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Hawk"].exists)

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
        XCTAssertTrue(app.staticTexts["Strike"].exists)
        app.buttons["Done"].tap()

        app.tabBars.buttons["Pets"].tap()
        XCTAssertTrue(app.staticTexts["Wolf"].waitForExistence(timeout: 5))
        app.buttons["Wolf collection card"].tap()
        XCTAssertTrue(app.staticTexts["Health"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6/6 HP"].exists)
        XCTAssertTrue(app.staticTexts["Strike"].exists)
        app.buttons["Done"].tap()
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
        app.buttons["Done"].tap()

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
        app.buttons["Done"].tap()
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
        app.buttons["Done"].tap()

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
}
