import XCTest

final class SearchUITests: TrinketUITestCase {
    func testSearchFlow() {
        launchApp(arguments: TestLaunchArg.allForTab("search"))
        search.assertEmptyState()

        let searchField = search.searchField
        assertExists(searchField)
        searchField.tap()
        searchField.typeText("Knight")

        assertButtonExists(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        collection.openCombatantCard(named: "Knight")
        assertCombatantDetailSections()
        goBack()

        searchField.tap()
        replaceText(in: searchField, with: "Wolf")
        assertButtonExists(AccessibilityID.CombatantDetail.collectionCard(name: "Wolf"))

        replaceText(in: searchField, with: "Wand")
        assertItemCardExists("Wand")

        replaceText(in: searchField, with: "xyz123")
        search.assertNoResults()
    }
}
