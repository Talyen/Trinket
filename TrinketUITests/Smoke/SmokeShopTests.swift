import TrinketFeatureSupport
import XCTest

final class SmokeShopTests: TrinketUITestCase {
    func testMerchantPurchasePaysAndReturnsToPlay() throws {
        launchApp(arguments: TestLaunchArg.allForScreen("shop")
            + TestLaunchArg.completedStages((1 ... 7).map { "chapter-2-stage-\($0)" })
            + ["-starting-gold", "200"])
        let offers = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", AccessibilityID.Shop.offerCardSuffix))
        let detailBuy = button(AccessibilityID.Shop.detailBuyButton)
        let leave = button(AccessibilityID.Shop.leaveButton)
        assertExists(AccessibilityID.Shop.goldBalance)
        let goldBefore = try integer(in: any(AccessibilityID.Shop.goldBalance))
        assertExists(offers.firstMatch)
        let offerID = offers.firstMatch.identifier
        let offer = button(offerID)
        let buyID = AccessibilityID.Shop.buyButton(offerID: String(offerID.dropLast(AccessibilityID.Shop.offerCardSuffix.count)))
        assertExists(buyID)
        let price = try integer(in: button(buyID))
        scrollUntilVisible(offer, swipingUp: true, requireHittable: true)
        tapWhenReady(offer)
        // Artwork preparation presents the sheet asynchronously; its purchase footer is fixed.
        assertExists(detailBuy)
        XCTAssertEqual(try integer(in: detailBuy), price)
        tapWhenReady(detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        XCTAssertEqual(try integer(in: any(AccessibilityID.Shop.goldBalance)), goldBefore - price)

        scrollUntilVisible(leave, swipingUp: true, requireHittable: true)
        tapWhenReady(leave)
        play.assertLoaded()
    }
}
