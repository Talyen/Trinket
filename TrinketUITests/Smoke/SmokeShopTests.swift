import TrinketFeatureSupport
import XCTest

final class SmokeShopTests: TrinketUITestCase {
    #if DEBUG
    func testTerminalPurchaseFailureOffersRetryWithoutSpendingGold() throws {
        launchApp(arguments: TestLaunchArg.allForScreen("shop")
            + ["-development-unlocked", "-terminal-shop-save-failure", "-starting-gold", "200"])
        let offers = app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", AccessibilityID.Shop.offerCardSuffix))
        let gold = app.descendants(matching: .any).matching(identifier: AccessibilityID.Shop.goldBalance).firstMatch
        assertExists(gold)
        let goldBefore = try integer(in: gold)
        XCTAssertTrue(app.scrollUntilVisible(offers.firstMatch, swipingUp: true, requireHittable: true))
        let offerID = offers.firstMatch.identifier
        let gridBuy = button(AccessibilityID.Shop.buyButton(offerID: String(offerID.dropLast(AccessibilityID.Shop.offerCardSuffix.count))))
        let price = try integer(in: gridBuy)
        tapWhenReady(offers.firstMatch)
        let buy = button(AccessibilityID.Shop.detailBuyButton)
        assertExists(buy)
        let initialLabel = buy.label

        tapWhenReady(buy)
        waitUntil("A failed purchase must offer a visible retry") { buy.label != initialLabel }
        tapWhenReady(buy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        waitUntil("A successful retry must debit its price") { (try? self.integer(in: gold)) == goldBefore - price }
    }
    #endif

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
        XCTAssertTrue(
            app.scrollUntilVisible(offers.firstMatch, swipingUp: true, requireHittable: true),
            "A merchant offer must be reachable",
        )
        let offerID = offers.firstMatch.identifier
        let offer = button(offerID)
        let buyID = AccessibilityID.Shop.buyButton(offerID: String(offerID.dropLast(AccessibilityID.Shop.offerCardSuffix.count)))
        let price = try integer(in: button(buyID))
        tapWhenReady(offer)
        assertExists(detailBuy, message: "Tapping merchant offer '\(offerID)' must open its purchase detail")
        // Native presentation can expose the footer before it has a valid activation frame.
        let windowBounds = app.frame
        waitUntil("Merchant detail purchase control must have an on-screen frame") {
            guard let bounds = trinketOnMainActor({ try? detailBuy.snapshot().frame }),
                  !bounds.isEmpty
            else { return false }
            return windowBounds.contains(bounds)
        }
        XCTAssertEqual(try integer(in: detailBuy), price)
        tapWhenReady(detailBuy)
        assertDoesNotExist(AccessibilityID.Shop.detailBuyButton)
        waitUntil("The merchant must debit its displayed price") {
            (try? self.integer(in: goldBalance)) == goldBefore - price
        }

        reveal(leave)
        tapWhenReady(leave)
        play.assertLoaded()
    }
}
