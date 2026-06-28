import XCTest

final class SearchUITests: XCTestCase {
    func testSearchFlow() {
        let app = createAndLaunchApp()

        // 1. Go to the native Search tab
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(app.staticTexts["Heroes, Pets, and Items"].waitForExistence(timeout: 5))

        // 2. Search for Paladin
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Paladin")
        
        XCTAssertTrue(app.buttons["Paladin collection card"].waitForExistence(timeout: 5))
        app.buttons["Paladin collection card"].tap()
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        goBack(in: app) // Back to search results

        // 3. Search for Wolf
        searchField.tap()
        searchField.typeText(String(repeating: "\u{0008}", count: "Paladin".count))
        searchField.typeText("Wolf")
        XCTAssertTrue(app.buttons["Wolf collection card"].waitForExistence(timeout: 5))
        app.buttons["Wolf collection card"].tap()
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))
        goBack(in: app)

        // 4. Search for Wand
        searchField.tap()
        searchField.typeText(String(repeating: "\u{0008}", count: "Wolf".count))
        searchField.typeText("Wand")
        XCTAssertTrue(app.buttons["Kindled Ember Wand item card"].waitForExistence(timeout: 5))
        app.buttons["Kindled Ember Wand item card"].tap()
        XCTAssertTrue(app.staticTexts["Kindled Ember Wand"].waitForExistence(timeout: 5))
        goBack(in: app)

        // 5. Search invalid
        searchField.tap()
        searchField.typeText(String(repeating: "\u{0008}", count: "Wand".count))
        searchField.typeText("xyz123")
        XCTAssertTrue(app.staticTexts["No Results Found"].waitForExistence(timeout: 5))
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
