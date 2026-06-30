import XCTest

final class SearchUITests: TrinketUITestCase {
    func testSearchFlow() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        app.tabBars.buttons["Search"].tap()
        assertExists("Heroes, Pets, and Items")

        let searchField = app.searchFields.firstMatch
        assertExists(searchField)
        searchField.tap()
        searchField.typeText("Knight")

        assertExists("Knight collection card")
        app.buttons["Knight collection card"].tap()
        assertExists("Stats")
        assertExists("Health")
        assertExists("10/10")
        goBack()

        searchField.tap()
        searchField.typeText(String(repeating: "\u{0008}", count: "Knight".count))
        searchField.typeText("Wolf")
        assertExists("Wolf collection card")
        app.buttons["Wolf collection card"].tap()
        assertExists("Stats")
        assertExists("Health")
        assertExists("6/6")
        goBack()

        searchField.tap()
        searchField.typeText(String(repeating: "\u{0008}", count: "Wolf".count))
        searchField.typeText("Wand")
        assertExists("Kindled Ember Wand item card")
        app.buttons["Kindled Ember Wand item card"].tap()
        assertExists("Kindled Ember Wand")
        goBack()

        searchField.tap()
        searchField.typeText(String(repeating: "\u{0008}", count: "Wand".count))
        searchField.typeText("xyz123")
        assertExists("No Results Found")
    }
}
