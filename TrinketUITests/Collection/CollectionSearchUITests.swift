import XCTest

final class CollectionSearchUITests: TrinketUITestCase {
    func testCollectionSearchFlow() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()

        let searchField = collection.searchField
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
        collection.assertSearchNoResults()
    }
}
