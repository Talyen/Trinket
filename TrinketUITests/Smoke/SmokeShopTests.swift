import TrinketFeatureSupport
import XCTest

final class SmokeShopTests: TrinketUITestCase {
    func testMerchantPurchasePaysForAnOwnedItemAndReturnsToPlay() throws {
        launchApp(arguments: TestLaunchArg.allForShop()
            + TestLaunchArg.completedStages((1 ... 7).map { "chapter-2-stage-\($0)" })
            + ["-starting-gold", "200"])
        let shop = ShopScreen(app: app)
        assertExists(AccessibilityID.Shop.goldBalance)
        let goldBefore = try integer(in: any(AccessibilityID.Shop.goldBalance))
        let offer = shop.offerCards.firstMatch
        scrollUntilVisible(offer, swipingUp: true, requireHittable: true)
        tapWhenReady(offer)
        assertExists(shop.detailBuy)
        let price = try integer(in: shop.detailBuy)
        let detailPrefix = AccessibilityID.LoadoutPicker.itemDetail("")
        let detail = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", detailPrefix)).firstMatch
        assertExists(detail)
        let itemID = String(detail.identifier.dropFirst(detailPrefix.count))
        let categories = [
            "BASIC": AccessibilityID.Collection.basicGearCategory,
            "ASTRAL": AccessibilityID.Collection.astralGearCategory,
            "TRINKET": AccessibilityID.Collection.trinketsCategory,
        ]
        let category = try XCTUnwrap(categories.first { app.staticTexts[$0.key].exists }?.value)
        tapWhenReady(shop.detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        XCTAssertEqual(try integer(in: any(AccessibilityID.Shop.goldBalance)), goldBefore - price)

        tapWhenReady(offer)
        assertExists(shop.detailBuy)
        XCTAssertFalse(shop.detailBuy.isEnabled, "Sold stock must not charge the player again")
        dismissSheet(AccessibilityID.LoadoutPicker.itemDetail(itemID))
        scrollUntilVisible(shop.leaveButton, swipingUp: true, requireHittable: true)
        tapWhenReady(shop.leaveButton)
        play.assertLoaded()
        tabBar.selectCollection()
        assertExistsAfterScroll(category, requireHittable: true)
        tapButton(category)
        let ownedItem = AccessibilityID.Collection.itemCard(itemID: itemID)
        assertExistsAfterScroll(ownedItem, requireHittable: true)
        XCTAssertTrue(button(ownedItem).isEnabled, "The purchased item must be available in Collection")
    }
}
