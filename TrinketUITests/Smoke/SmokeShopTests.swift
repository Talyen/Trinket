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
        let offer = shop.offerCards.firstMatch
        scrollUntilVisible(offer, swipingUp: true, requireHittable: true)
        tapWhenReady(offer)
        assertExists(shop.detailBuy)
        let price = try integer(in: shop.detailBuy)
        tapWhenReady(shop.detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        XCTAssertEqual(try integer(in: any(AccessibilityID.Shop.goldBalance)), goldBefore - price)

        scrollUntilVisible(shop.leaveButton, swipingUp: true, requireHittable: true)
        tapWhenReady(shop.leaveButton)
        play.assertLoaded()
    }
}
