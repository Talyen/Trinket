import XCTest

final class BattleFlowUITests: XCTestCase {
    func testBattleFlowAndCombatLoops() {
        let app = createAndLaunchApp()

        // 1. Start Battle (Mage & Drake)
        XCTAssertTrue(app.staticTexts["Choose a mode to start building the core loop."].waitForExistence(timeout: 5))
        app.staticTexts["Battle"].tap()

        XCTAssertTrue(app.staticTexts["Select Hero"].waitForExistence(timeout: 5))
        app.staticTexts["Mage"].tap()

        XCTAssertTrue(app.staticTexts["Select Pet"].waitForExistence(timeout: 5))
        app.staticTexts["Drake"].tap()

        // 3. Verify Battle Flow is Reachable and inspect combatant details in battle
        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mage card"].exists)
        XCTAssertTrue(app.buttons["Drake card"].exists)
        let pauseToggle = app.buttons["Battle Pause Toggle"]
        XCTAssertTrue(pauseToggle.exists)

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



    private func createAndLaunchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-disableAnimations"] + arguments
        app.launch()
        return app
    }
}
