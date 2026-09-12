import TrinketFeatureSupport
import XCTest

final class SmokeShopTests: TrinketUITestCase {
    private var shop: ShopScreen {
        ShopScreen(app: app)
    }

    func testMerchantShopPurchaseFromDetailAndLeaveReturnsToPlay() {
        launchApp(
            arguments: TestLaunchArg.allForShop()
                + TestLaunchArg.completedStages([
                    "chapter-2-stage-1",
                    "chapter-2-stage-2",
                    "chapter-2-stage-3",
                    "chapter-2-stage-4",
                    "chapter-2-stage-5",
                    "chapter-2-stage-6",
                    "chapter-2-stage-7",
                ])
                + ["-starting-gold", "200", "-launch-preparation-delay", "8"],
            waitForPreparation: false,
        )

        assertExists(AccessibilityID.Screen.launchWarmup)
        let prematureShop = XCTNSPredicateExpectation(
            predicate: NSPredicate { [self] _, _ in any(AccessibilityID.Shop.goldBalance).exists },
            object: nil,
        )
        prematureShop.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [prematureShop], timeout: 3), .completed)
        XCTAssertTrue(any(AccessibilityID.Screen.launchWarmup).exists)
        app.terminate()
        app.launch()
        waitForLaunchPreparation()

        assertExists(AccessibilityID.Shop.goldBalance)

        let firstOfferCard = shop.offerCards.firstMatch
        assertExists(firstOfferCard)
        tapWhenReady(firstOfferCard)

        assertExists(shop.detailBuy)
        XCTAssertTrue(shop.detailBuy.isEnabled, "Expected shop detail buy control to be enabled")
        tapWhenReady(shop.detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton, timeout: 5)

        tapWhenReady(firstOfferCard)
        assertExists(shop.detailBuy)
        XCTAssertFalse(shop.detailBuy.isEnabled, "Sold stock remains inspectable but cannot be purchased again")
        dismissSheet()

        scrollUntilVisible(shop.leaveButton, swipingUp: true, requireHittable: true)
        shop.leaveButton.tap()
        play.assertLoaded()
        play.openCampaign(number: 2)
    }
}
