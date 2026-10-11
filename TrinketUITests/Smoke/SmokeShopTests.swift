import TrinketFeatureSupport
import XCTest

final class SmokeShopTests: TrinketUITestCase {
    func testMerchantPurchasePaysAndReturnsToPlay() throws {
        launchApp(arguments: TestLaunchArg.allForShop()
            + TestLaunchArg.completedStages((1 ... 7).map { "chapter-2-stage-\($0)" })
            + ["-starting-gold", "200"])
        let shop = ShopScreen(app: app)
        assertExists(AccessibilityID.Shop.goldBalance)
        let goldBefore = try integer(in: any(AccessibilityID.Shop.goldBalance))
        assertExists(shop.offerCards.firstMatch)
        let offerID = shop.offerCards.firstMatch.identifier
        let offer = button(offerID)
        let buyID = AccessibilityID.Shop.buyButton(offerID: String(offerID.dropLast(AccessibilityID.Shop.offerCardSuffix.count)))
        assertExists(buyID)
        let price = try integer(in: button(buyID))
        scrollUntilVisible(offer, swipingUp: true, requireHittable: true)
        tapWhenReady(offer)
        // Artwork preparation presents the sheet asynchronously; its purchase footer is fixed.
        assertExists(shop.detailBuy)
        XCTAssertEqual(try integer(in: shop.detailBuy), price)
        tapWhenReady(shop.detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        XCTAssertEqual(try integer(in: any(AccessibilityID.Shop.goldBalance)), goldBefore - price)

        scrollUntilVisible(shop.leaveButton, swipingUp: true, requireHittable: true)
        tapWhenReady(shop.leaveButton)
        play.assertLoaded()
    }
}
