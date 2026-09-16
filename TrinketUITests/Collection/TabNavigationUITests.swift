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
            // Lock state resolves asynchronously after the grid loads; poll
            // within the standard budget instead of asserting immediately.
            let locked = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in !card.isEnabled },
                object: nil,
            )
            XCTAssertEqual(
                XCTWaiter.wait(for: [locked], timeout: TrinketUITestCase.defaultTimeout),
                .completed,
                "Locked item '\(itemID)' reported enabled",
            )
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
