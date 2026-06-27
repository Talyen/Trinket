import XCTest

final class TabNavigationUITests: XCTestCase {
    func testTabNavigationAndInspectionFlow() {
        let app = createAndLaunchApp()

        // 1. Start at Play dashboard
        XCTAssertTrue(app.staticTexts["Choose a mode to start building the core loop."].waitForExistence(timeout: 5))

        // 2. Go to Heroes tab -> Paladin Details -> Paladin Item Loadout
        app.tabBars.buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Paladin"].waitForExistence(timeout: 5))
        app.buttons["Paladin collection card"].tap()
        
        XCTAssertTrue(app.staticTexts["Health"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10/10 HP"].exists)
        XCTAssertTrue(app.staticTexts["Level 2"].exists)
        XCTAssertTrue(app.staticTexts["35/120 XP"].exists)
        
        // Verify item loadout shows shared slots
        app.buttons["Paladin item loadout"].tap()
        XCTAssertTrue(app.staticTexts["Weapon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Armor"].exists)
        XCTAssertTrue(app.staticTexts["Accessory"].exists)
        XCTAssertTrue(app.staticTexts["Kindled Ember Wand"].exists)
        XCTAssertTrue(app.staticTexts["Patient Leather Gloves"].exists)
        XCTAssertTrue(app.staticTexts["River Charm of Sparks"].exists)
        
        // Go back to Paladin details, then back to Heroes list
        goBack(in: app)
        goBack(in: app)

        // 3. Switch to Pets segment picker, verify Wolf Details
        app.segmentedControls["Heroes collection switcher"].buttons["Pets"].tap()
        XCTAssertTrue(app.staticTexts["Wolf"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Hawk"].exists)
        app.buttons["Wolf collection card"].tap()
        
        XCTAssertTrue(app.staticTexts["Health"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6/6 HP"].exists)
        XCTAssertTrue(app.staticTexts["Level 2"].exists)
        XCTAssertTrue(app.staticTexts["12/100 XP"].exists)
        
        // Go back to Pets list
        goBack(in: app)

        // 4. Go to Inventory tab -> Kindled Ember Wand Details
        app.tabBars.buttons["Inventory"].tap()
        XCTAssertTrue(app.buttons["Kindled Ember Wand item card"].waitForExistence(timeout: 5))
        app.buttons["Kindled Ember Wand item card"].tap()

        XCTAssertTrue(app.staticTexts["Kindled Ember Wand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Ember Wand • Weapon"].exists)
        XCTAssertTrue(app.staticTexts["Warm Focus"].exists)
        XCTAssertTrue(app.staticTexts["+3% fire-themed ability power."].exists)
        
        // Go back to Inventory list
        goBack(in: app)

        // 5. Go to Homestead tab
        app.tabBars.buttons["Homestead"].tap()
        XCTAssertTrue(app.staticTexts["A future base for crafting, upgrades, and long-term progression."].waitForExistence(timeout: 5))

        // 6. Go to Options tab
        app.tabBars.buttons["Options"].tap()
        XCTAssertTrue(app.staticTexts["Settings, account, accessibility, audio, and credits will live here."].waitForExistence(timeout: 5))

        // 7. Return to Play tab
        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Choose a mode to start building the core loop."].waitForExistence(timeout: 5))
    }

    private func goBack(in app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    private func createAndLaunchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-disableAnimations"] + arguments
        app.launch()
        return app
    }
}
