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
        XCTAssertTrue(scrollUntilVisible(offers.firstMatch, swipingUp: true, requireHittable: true), "A merchant offer must be reachable")
        let offerID = offers.firstMatch.identifier
        let offer = button(offerID)
        let buyID = AccessibilityID.Shop.buyButton(offerID: String(offerID.dropLast(AccessibilityID.Shop.offerCardSuffix.count)))
        let price = try integer(in: button(buyID))
        tapWhenReady(offer)
        let didOpenDetail = detailBuy.trinketWaitForExistence(timeout: Self.defaultTimeout)
        let openedDetailBuy = try XCTUnwrap(
            didOpenDetail ? detailBuy : nil,
            "Tapping merchant offer '\(offerID)' must open its detail before checking the purchase frame",
        )
        // Native presentation can expose the footer before it has a valid activation frame.
        let windowBounds = app.frame
        waitUntil("Merchant detail purchase control must have an on-screen frame") {
            guard let bounds = trinketOnMainActor({ try? openedDetailBuy.snapshot().frame }),
                  !bounds.isEmpty
            else { return false }
            return windowBounds.contains(bounds)
        }
        XCTAssertEqual(try integer(in: openedDetailBuy), price)
        tapWhenReady(openedDetailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        waitUntil("The merchant must debit its displayed price") {
            (try? self.integer(in: goldBalance)) == goldBefore - price
        }

        scrollUntilVisible(leave, swipingUp: true, requireHittable: true)
        tapWhenReady(leave)
        play.assertLoaded()
    }
}
