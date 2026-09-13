import TrinketFeatureSupport
import XCTest

final class TabNavigationUITests: TrinketUITestCase {
    func testLockedAuthoredItemsCannotOpenDetails() {
        launchApp(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "collection"])
        collection.assertLoaded()

        for (categoryID, itemID) in [
            (AccessibilityID.Collection.uniqueGearCategory, "wardbreaker"),
            (AccessibilityID.Collection.trinketsCategory, "bone_charm"),
        ] {
            assertExistsAfterScroll(categoryID, requireHittable: true)
            tapButton(categoryID)
            let cardID = AccessibilityID.Collection.itemCard(itemID: itemID)
            assertExists(cardID)
            let card = app.descendants(matching: .any)[cardID].firstMatch
            XCTAssertFalse(card.isEnabled)
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            assertDoesNotExist(AccessibilityID.LoadoutPicker.itemDetail(itemID))
            assertExists(cardID)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            add(attachment)
            goBack()
        }
    }
}
