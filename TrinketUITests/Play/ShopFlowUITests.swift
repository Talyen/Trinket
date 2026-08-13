import TrinketFeatureSupport
import XCTest

/// Exhaustive merchant shop journey via deep link (kept out of smoke).
final class ShopFlowUITests: TrinketUITestCase {
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

        let offerCards = app.buttons.matching(
            NSPredicate(format: "identifier ENDSWITH %@", " shop offer")
        )
        let firstOfferCard = offerCards.firstMatch
        assertExists(firstOfferCard)
        tapWhenReady(firstOfferCard)

        let detailBuy = button(AccessibilityID.Shop.detailBuyButton)
        assertExists(detailBuy)
        XCTAssertTrue(detailBuy.isEnabled, "Expected shop detail buy control to be enabled")
        tapWhenReady(detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton, timeout: 5)

        let leaveButton = button(AccessibilityID.Shop.leaveButton)
        scrollUntilVisible(leaveButton, swipingUp: true, requireHittable: true)
        tapButton(AccessibilityID.Shop.leaveButton)
        play.openCampaign()
        play.assertCampaignLoaded(number: 2)
    }
}
