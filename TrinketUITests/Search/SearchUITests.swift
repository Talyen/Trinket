import XCTest

final class SearchUITests: TrinketUITestCase {
    func testSearchFlow() {
        launchApp(arguments: TestLaunchArg.allForTab("search"))
        search.assertEmptyState()

        let searchField = search.searchField
        assertExists(searchField)
        searchField.tap()
        searchField.typeText("Knight")

        assertButtonExists("Knight collection card")
        collection.openCombatantCard(named: "Knight")
        assertCombatantDetailSections()
        goBack()

        searchField.tap()
        clearAndEnterText(searchField, "Wolf")
        assertButtonExists("Wolf collection card")
        collection.openCombatantCard(named: "Wolf")
        assertCombatantDetailSections()
        goBack()

        searchField.tap()
        clearAndEnterText(searchField, "Wand")
        assertItemCardExists("Wand")
        collection.openItemCard(named: "Wand")
        assertExists("Wand")
        goBack()

        searchField.tap()
        clearAndEnterText(searchField, "xyz123")
        search.assertNoResults()
    }
}
