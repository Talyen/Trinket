import XCTest

final class BattleFlowUITests: XCTestCase {
    func testBattleFlowAndCombatLoops() {
        let app = createAndLaunchApp()

        // 1. Start Battle (Mage & Drake)
        XCTAssertTrue(app.staticTexts["Play"].waitForExistence(timeout: 5))
        app.staticTexts["Battle"].tap()

        XCTAssertTrue(app.staticTexts["Select Hero"].waitForExistence(timeout: 5))
        app.staticTexts["Mage"].tap()

        XCTAssertTrue(app.staticTexts["Select Pet"].waitForExistence(timeout: 5))
        app.staticTexts["Drake"].tap()

        // 3. Verify Battle Flow is Reachable and inspect combatant details in battle
        XCTAssertTrue(app.buttons["Training Slime card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Mage card"].exists)
        XCTAssertTrue(app.buttons["Drake card"].exists)
        XCTAssertFalse(app.buttons["End Battle"].exists)
        XCTAssertTrue(app.buttons["Battle Menu"].exists)

        XCTAssertFalse(app.staticTexts["Ember"].waitForExistence(timeout: 1))

        app.buttons["Mage card"].tap()
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        dismissSheet(in: app)

        // Switching away and tapping Play again should keep the active battle or show the Victory screen if completed.
        app.tabBars.buttons["Collection"].tap()
        XCTAssertTrue(app.staticTexts["Mage"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Play"].tap()

        let slimeCardExists = app.buttons["Training Slime card"].waitForExistence(timeout: 2)
        if slimeCardExists {
            XCTAssertFalse(app.staticTexts["Play Dashboard Header"].exists)
        } else {
            XCTAssertTrue(app.staticTexts["Victory"].exists)
        }

        // 5. Verify Victory screen is reached and rewards are presented
        XCTAssertTrue(app.staticTexts["Victory"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Experience"].exists)
        XCTAssertTrue(app.staticTexts["Rewards"].exists)
        XCTAssertTrue(app.buttons["Battle Again"].exists)
        XCTAssertFalse(app.buttons["End Battle"].exists)
        app.buttons["Battle Menu"].tap()
        XCTAssertTrue(app.buttons["Combat Log"].exists)
        XCTAssertFalse(app.buttons["Retreat"].exists)
        dismissMenu(in: app)
        XCTAssertFalse(app.buttons["Change Party"].exists)
    }

    private func dismissSheet(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.1, thenDragTo: end)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    private func dismissMenu(in app: XCUIApplication) {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.08)).tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    private func createAndLaunchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-disableAnimations"] + arguments
        app.launch()
        return app
    }
}
