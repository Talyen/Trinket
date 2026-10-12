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
        // iOS 18 mirrors this one wallet's semantics on its native toolbar host and child.
        let goldBalance = app.descendants(matching: .any).matching(identifier: AccessibilityID.Shop.goldBalance).firstMatch
        assertExists(goldBalance)
        let goldBefore = try integer(in: goldBalance)
        assertExists(offers.firstMatch)
        let offerID = offers.firstMatch.identifier
        let offer = button(offerID)
        let buyID = AccessibilityID.Shop.buyButton(offerID: String(offerID.dropLast(AccessibilityID.Shop.offerCardSuffix.count)))
        assertExists(buyID)
        let price = try integer(in: button(buyID))
        scrollUntilVisible(offer, swipingUp: true, requireHittable: true)
        tapWhenReady(offer)
        // Artwork preparation presents the sheet asynchronously; its purchase footer is fixed.
        waitUntil("Merchant detail must expose its matching purchase price") {
            detailBuy.exists && detailBuy.isHittable && (try? self.integer(in: detailBuy)) == price
        }
        tapWhenReady(detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        XCTAssertEqual(try integer(in: goldBalance), goldBefore - price)

        scrollUntilVisible(leave, swipingUp: true, requireHittable: true)
        tapWhenReady(leave)
        play.assertLoaded()
    }
}
