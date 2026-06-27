import XCTest

final class BattleFlowUITests: XCTestCase {
    func testBattleFlowAndCombatLoops() {
        let app = createAndLaunchApp()

        // 1. Verify Ability Loadout Selection UI (toggle basic abilities in Heroes tab)
        app.tabBars.buttons["Heroes"].tap()
        app.segmentedControls["Heroes collection switcher"].buttons["Heroes"].tap()
        XCTAssertTrue(app.staticTexts["Mage"].waitForExistence(timeout: 5))
        app.buttons["Mage collection card"].tap()
        
        app.buttons["Mage ability loadout"].tap()
        XCTAssertTrue(app.staticTexts["Abilities"].waitForExistence(timeout: 5))
        
        // Tap Basic Strike to select it, then tap Basic Ember to select it back
        app.buttons["Basic Strike ability card"].tap()
        app.buttons["Basic Ember ability card"].tap()

        // Pop twice to return to Heroes tab root before switching tabs
        goBack(in: app) // Mage ability loadout -> Mage detail view
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
        XCTAssertFalse(app.staticTexts["Ember"].waitForExistence(timeout: 1))

        app.buttons["Mage card"].tap()
        XCTAssertTrue(app.staticTexts["Ember"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 Physical damage. Apply Burn 1 for 2 ticks."].exists)
        dismissSheet(in: app)

        // Since testing timer ticks at 0.5s, Tick 3 (Burn damage tick) fires at 1.5s.
        // Tapping Mage and dismissing the sheet takes ~0.5s. Wait 1.1s to be at ~1.6s (before Tick 4 at 2.0s):
        RunLoop.current.run(until: Date().addingTimeInterval(1.1))

        // 5. Verify Battle Log contains combat events (Ember and Burn damage)
        app.buttons["Battle Log"].tap()
        XCTAssertTrue(app.staticTexts["Mage uses Ember for 1 Physical damage and applies Burn 1 for 2 ticks."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Training Slime takes 2 Burn damage."].exists)
        app.buttons["Done"].tap()

        // 6. Verify Victory screen is reached and rewards are presented
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
