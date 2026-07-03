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
        replaceText(in: searchField, with: "Wolf")
        assertButtonExists("Wolf collection card")
        collection.openCombatantCard(named: "Wolf")
        assertCombatantDetailSections()
        goBack()

        replaceText(in: searchField, with: "Wand")
        assertItemCardExists("Wand")
        collection.openItemCard(named: "Wand")
        assertExists("Wand")
        goBack()

        replaceText(in: searchField, with: "xyz123")
        search.assertNoResults()
    }
}
