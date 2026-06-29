import XCTest

final class SmokeSearchTests: TrinketUITestCase {
    func testSearchTabExists() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Search"].tap()
        assertExists("Heroes, Pets, and Items")
    }

    func testSearchFindsPaladin() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Search"].tap()

        let searchField = app.searchFields.firstMatch
        assertExists(searchField)
        searchField.tap()
        searchField.typeText("Knight")

        assertExists("Knight collection card")
    }
}
