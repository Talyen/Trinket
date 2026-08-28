import TrinketFeatureSupport
import XCTest

final class ShopFlowUITests: TrinketUITestCase {
    private var shop: ShopScreen {
        ShopScreen(app: app)
    }

    func testMerchantShopPurchaseFromDetailAndLeaveReturnsToPlay() {
        launchApp(arguments: TestLaunchArg.allForShop()
            + TestLaunchArg.completedStages([
                "chapter-2-stage-1",
                "chapter-2-stage-2",
                "chapter-2-stage-3",
                "chapter-2-stage-4",
                "chapter-2-stage-5",
                "chapter-2-stage-6",
                "chapter-2-stage-7",
            ])
            + ["-starting-gold", "200"])

        let firstOfferCard = shop.offerCards.firstMatch
        assertExists(firstOfferCard)
        tapWhenReady(firstOfferCard)

        assertExists(shop.detailBuy)
        XCTAssertTrue(shop.detailBuy.isEnabled, "Expected shop detail buy control to be enabled")
        tapWhenReady(shop.detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton, timeout: 5)

        scrollUntilVisible(shop.leaveButton, swipingUp: true, requireHittable: true)
        shop.leaveButton.tap()
        play.openCampaign()
        play.assertCampaignLoaded(number: 2)
    }
}
