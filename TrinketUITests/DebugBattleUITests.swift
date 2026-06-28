import XCTest

final class DebugBattleUITests: XCTestCase {
    func testDebugBattleHarnessStartsPausedAndCanStepToVictory() {
        let app = createAndLaunchApp(arguments: [
            "-battleDebugHarness",
            "enabled",
            "-battleDebugHero",
            "Mage",
            "-battleDebugPet",
            "Drake"
        ])

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

        app.buttons["Battle Menu"].tap()
        XCTAssertTrue(app.buttons["Pause Battle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Retreat"].exists)
        XCTAssertTrue(app.buttons["Battle Details"].waitForExistence(timeout: 5))
        app.buttons["Battle Details"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Mage uses Ember for 1 Physical damage and applies Burn 1 for 2 ticks."].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        app.buttons["Debug Finish Battle"].tap()
        XCTAssertTrue(app.staticTexts["Victory"].waitForExistence(timeout: 5))
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
