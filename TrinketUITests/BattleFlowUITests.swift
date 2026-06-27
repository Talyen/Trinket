import XCTest

final class BattleFlowUITests: XCTestCase {
    func testBattleFlowAndCombatLoops() {
        let app = createAndLaunchApp()

        // 1. Verify Ability Loadout Selection UI (toggle basic abilities in Heroes tab)
        app.tabBars.buttons["Heroes"].tap()
        app.segmentedControls["Heroes collection switcher"].buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Mage"].waitForExistence(timeout: 5))
        app.buttons["Mage collection card"].tap()
        
        XCTAssertTrue(app.buttons["Basic ability slot"].waitForExistence(timeout: 5))
        
        // Tap Basic Strike to select it, then tap Basic Ember to select it back
        app.buttons["Basic ability slot"].tap()
        XCTAssertTrue(app.staticTexts["Choose Basic"].waitForExistence(timeout: 5))
        app.buttons["Basic Strike ability card"].tap()
        XCTAssertTrue(app.staticTexts["Strike"].waitForExistence(timeout: 5))

        app.buttons["Basic ability slot"].tap()
        XCTAssertTrue(app.staticTexts["Choose Basic"].waitForExistence(timeout: 5))
        app.buttons["Basic Ember ability card"].tap()
        XCTAssertTrue(app.staticTexts["Ember"].waitForExistence(timeout: 5))

        // Pop once to return to Heroes tab root before switching tabs
        goBack(in: app) // Mage detail view -> Heroes list root

        // 2. Start Battle (Mage & Drake)
        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Battle"].waitForExistence(timeout: 5))
        app.staticTexts["Battle"].tap()

        XCTAssertTrue(app.staticTexts["Select Hero"].waitForExistence(timeout: 5))
        app.staticTexts["Mage"].tap()

        XCTAssertTrue(app.staticTexts["Select Pet"].waitForExistence(timeout: 5))
        app.staticTexts["Drake"].tap()

        // 3. Verify Battle Flow is Reachable and inspect combatant details in battle
        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mage card"].exists)
        XCTAssertTrue(app.buttons["Drake card"].exists)
        let pauseToggle = app.descendants(matching: .any)["Battle Pause Toggle"]
        let speedToggle = app.descendants(matching: .any)["Battle Speed Toggle"]
        XCTAssertTrue(pauseToggle.exists)
        XCTAssertTrue(speedToggle.exists)

        speedToggle.tap()
        XCTAssertEqual(speedToggle.value as? String, "2x")
        speedToggle.tap()
        XCTAssertEqual(speedToggle.value as? String, "1x")
        pauseToggle.tap()
        XCTAssertEqual(pauseToggle.value as? String, "Paused")

        // Switching away and tapping Play again should keep the active battle.
        app.tabBars.buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Mage"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Play"].tap()
        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Choose a mode to start building the core loop."].exists)

        XCTAssertFalse(app.staticTexts["Ember"].waitForExistence(timeout: 1))

        app.buttons["Mage card"].tap()
        XCTAssertTrue(app.staticTexts["Ember"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 Physical damage. Apply Burn 1 for 2 ticks."].exists)
        dismissSheet(in: app)
        pauseToggle.tap()
        XCTAssertEqual(pauseToggle.value as? String, "Running")

        // 5. Verify Victory screen is reached and rewards are presented
        XCTAssertTrue(app.staticTexts["Victory"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Experience"].exists)
        XCTAssertTrue(app.staticTexts["Rewards"].exists)
        XCTAssertTrue(app.buttons["Battle Again"].exists)
        XCTAssertFalse(app.buttons["Change Party"].exists)
    }

    private func dismissSheet(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
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
