import StoreKitTest
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseUITests: FullGameStoreKitUITestCase {
    func testAskToBuyAndRestore() throws {
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
        XCTAssertEqual(XCTWaiter.wait(for: [deferred], timeout: 10), .completed)
        assertDoesNotExist(AccessibilityID.FullGame.status)
        let pending = try XCTUnwrap(session.allTransactions().first)
        XCTAssertEqual(pending.state, .deferred)
        assertExists(AccessibilityID.FullGame.offer)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 10)
        session.askToBuyEnabled = false
        assertDoesNotExist(AccessibilityID.FullGame.options, timeout: 10)

        assertExistsAfterScroll(AccessibilityID.FullGame.restore, requireHittable: true)
        tapButton(AccessibilityID.FullGame.restore)
        let restored = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"),
            object: button(AccessibilityID.FullGame.restore),
        )
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
        assertDoesNotExist(AccessibilityID.FullGame.options)
        assertDoesNotExist(AccessibilityID.FullGame.status)
    }
}
