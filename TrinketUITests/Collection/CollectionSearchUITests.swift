import XCTest

final class CollectionSearchUITests: TrinketUITestCase {
    func testCollectionSearchFlow() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        collection.assertLoaded()

        let searchField = collection.searchField
        assertExists(searchField)
        replaceText(in: searchField, with: "Knight")

        assertButtonExists(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        collection.openCombatantCard(named: "Knight")
        assertCombatantDetailSections()
        dismissSheet()

        replaceText(in: searchField, with: "Wolf")
        assertButtonExists(AccessibilityID.CombatantDetail.collectionCard(name: "Wolf"))

        replaceText(in: searchField, with: "Wand")
        assertItemCardExists("Wand")

        replaceText(in: searchField, with: "xyz123")
        // Dismiss the keyboard so ContentUnavailableView is fully in the hierarchy.
        if app.keyboards.element.exists {
            app.swipeDown()
        }
        collection.assertSearchNoResults()
    }
}
