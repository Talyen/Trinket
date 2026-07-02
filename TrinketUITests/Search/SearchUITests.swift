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
        goBack()

        searchField.tap()
        clearAndEnterText(searchField, "Wolf")
        assertExists("Wolf collection card")
        app.buttons["Wolf collection card"].tap()
        assertExists("Stats")
        assertExists("Health")
        goBack()

        searchField.tap()
        clearAndEnterText(searchField, "Wand")
        assertItemCardExists("Wand")
        app.buttons.matching(identifier: "Wand item card").firstMatch.tap()
        assertExists("Wand")
        goBack()

        searchField.tap()
        clearAndEnterText(searchField, "xyz123")
        assertExists("No Results Found")
    }
}
