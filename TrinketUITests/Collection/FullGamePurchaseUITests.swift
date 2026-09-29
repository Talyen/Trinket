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
        let deferred = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in session.allTransactions().contains { $0.state == .deferred } },
            object: nil,
        )
        XCTAssertEqual(XCTWaiter.wait(for: [deferred], timeout: 20), .completed)
        assertDoesNotExist(AccessibilityID.FullGame.status)
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
            predicate: NSPredicate(format: "enabled == true"),
            object: button(AccessibilityID.FullGame.restore),
        )
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 20), .completed)
        assertDoesNotExist(AccessibilityID.FullGame.options)
        assertDoesNotExist(AccessibilityID.FullGame.status)
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
        XCTAssertFalse(app.alerts.firstMatch.exists)
        tapButton(AccessibilityID.Options.resetProgressCancel)
        assertExists(AccessibilityID.Options.resetProgressButton)
        tapButton(AccessibilityID.Options.resetProgressButton)
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressConfirmation, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressConfirmation)
        assertExists(AccessibilityID.Onboarding.heroScreen, timeout: 20)
    }
}
