import XCTest

final class SearchUITests: TrinketUITestCase {
    func testSearchFlow() {
        launchApp(arguments: [TestLaunchArg.resetState])

        app.tabBars.buttons["Search"].tap()
        assertExists("Heroes, Pets, and Items")

        let searchField = app.searchFields.firstMatch
        assertExists(searchField)
        searchField.tap()
        searchField.typeText("Paladin")

        assertExists("Paladin collection card")
        app.buttons["Paladin collection card"].tap()
        assertExists("Stats")
        goBack()

        searchField.tap()
        searchField.typeText(String(repeating: "\u{0008}", count: "Paladin".count))
        searchField.typeText("Wolf")
        assertExists("Wolf collection card")
        app.buttons["Wolf collection card"].tap()
        assertExists("Stats")
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
