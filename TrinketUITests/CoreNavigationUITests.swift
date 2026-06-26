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
}
