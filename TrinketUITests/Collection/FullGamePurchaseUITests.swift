import StoreKitTest
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseUITests: FullGameStoreKitUITestCase {
    func testAskToBuyRestoreRefundAndRepurchase() throws {
        try skipUnavailablePurchaseAutomation()
        try launchAndAwaitOfferProduct(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"]) {
            assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
            tapButton(AccessibilityID.FullGame.options)
        }
        let session = try XCTUnwrap(storeSession)
        session.askToBuyEnabled = true
        tapButton(AccessibilityID.FullGame.purchase)
        assertExists(AccessibilityID.FullGame.status, timeout: 20)
        let pending = try XCTUnwrap(session.allTransactions().first)
        XCTAssertEqual(pending.state, .deferred)
        assertExists(AccessibilityID.FullGame.offer)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 20)
        session.askToBuyEnabled = false
        assertDoesNotExist(AccessibilityID.FullGame.options, timeout: 10)

        assertExistsAfterScroll(AccessibilityID.FullGame.restore, requireHittable: true)
        tapButton(AccessibilityID.FullGame.restore)
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Full Game restored."),
            object: any(AccessibilityID.FullGame.status),
        )
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 20), .completed)
        let purchase = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: purchase.identifier)
        assertExists(AccessibilityID.FullGame.options, timeout: 20)
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 20)
        XCTAssertEqual(session.allTransactions().count, 2)
    }

    func testGameplayResetReturnsToOnboarding() {
        launchApp(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"])
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressButton)
        tapWhenReady(app.alerts.buttons[AccessibilityID.Options.resetProgressConfirmation])
        assertExists(AccessibilityID.Onboarding.heroScreen, timeout: 20)
    }
}
