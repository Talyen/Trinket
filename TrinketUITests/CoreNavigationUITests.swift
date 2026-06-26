import XCTest

final class CoreNavigationUITests: XCTestCase {
    func testCoreTabsAreReachable() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Idle battles, encounter progress, and rewards will anchor the core loop here."].waitForExistence(timeout: 5))

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
        XCTAssertTrue(app.staticTexts["Idle battles, encounter progress, and rewards will anchor the core loop here."].waitForExistence(timeout: 5))
    }
}
