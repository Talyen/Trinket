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
        
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["10 HP"].exists)
        XCTAssertTrue(app.staticTexts["Level 2"].exists)
        XCTAssertTrue(app.staticTexts["35/120 XP"].exists)
        
        // Verify item slots open a focused picker for that slot
        app.swipeUp()
        XCTAssertTrue(app.buttons["Weapon item slot"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Armor item slot"].exists)
        XCTAssertTrue(app.buttons["Trinket item slot"].exists)
        XCTAssertTrue(app.staticTexts["Weapon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Armor"].exists)
        XCTAssertTrue(app.staticTexts["Trinket"].exists)
        XCTAssertTrue(app.staticTexts["Kindled Ember Wand"].exists)
        XCTAssertTrue(app.staticTexts["Patient Leather Gloves"].exists)
        XCTAssertTrue(app.staticTexts["River Charm of Sparks"].exists)

        app.buttons["Weapon item slot"].tap()
        XCTAssertTrue(app.staticTexts["Equip Weapon"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Equip Kindled Ember Wand"].exists)
        XCTAssertEqual(app.buttons["Equip Kindled Ember Wand"].value as? String, "Equipped")
        dismissSheet(in: app)
        
        // Verify Ability Loadout Selection UI (toggle basic abilities)
        XCTAssertTrue(app.buttons["Basic ability slot"].exists)
        app.buttons["Basic ability slot"].tap()
        XCTAssertTrue(app.staticTexts["Choose Basic"].waitForExistence(timeout: 5))
        app.buttons["Basic Shield Jab ability card"].tap()
        XCTAssertTrue(app.staticTexts["Shield Jab"].waitForExistence(timeout: 5))

        app.buttons["Basic ability slot"].tap()
        XCTAssertTrue(app.staticTexts["Choose Basic"].waitForExistence(timeout: 5))
        app.buttons["Basic Strike ability card"].tap()
        XCTAssertTrue(app.staticTexts["Strike"].waitForExistence(timeout: 5))
        
        // Go back to Heroes list
        goBack(in: app)

        // 3. Switch to Pets segment picker, verify Wolf Details
        app.segmentedControls["Heroes collection switcher"].buttons["Pets"].tap()
        XCTAssertTrue(app.staticTexts["Wolf"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Hawk"].exists)
        app.buttons["Wolf collection card"].tap()
        
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["6 HP"].exists)
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

        // 6. Return to Play tab
        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Choose a mode to start building the core loop."].waitForExistence(timeout: 5))
    }

    private func goBack(in app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    private func dismissSheet(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    private func createAndLaunchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-disableAnimations"] + arguments
        app.launch()
        return app
    }
}
