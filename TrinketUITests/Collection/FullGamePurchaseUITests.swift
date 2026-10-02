import Foundation
import StoreKit
import StoreKitTest
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseUITests: FullGameStoreKitUITestCase {
    func testAskToBuyKeepsContentLockedUntilApproval() throws {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer()
        let session = try XCTUnwrap(storeSession)
        session.askToBuyEnabled = true
        tapButton(AccessibilityID.FullGame.purchase)
        waitUntil("Purchase did not become pending") {
            session.allTransactions().contains { $0.state == .deferred }
        }
        assertExists(AccessibilityID.FullGame.offer)
        let pending = try XCTUnwrap(session.allTransactions().first { $0.state == .deferred })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
    }

    @MainActor
    func testExistingPurchaseUnlocksContentOnColdLaunch() async throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let session = try XCTUnwrap(storeSession)
        _ = try await session.buyProduct(identifier: "com.ryanmcintire.Trinket.fullgame")
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        assertDoesNotExist(AccessibilityID.FullGame.options)
        assertWarlockAccessible()
    }

    @MainActor
    func testFailedRestoreKeepsContentLockedAndAllowsPurchase() async throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let session = try XCTUnwrap(storeSession)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        launchApp(arguments: TestLaunchArg.allForTab("options"))
        assertExistsAfterScroll(AccessibilityID.FullGame.restore, requireHittable: true)
        tapButton(AccessibilityID.FullGame.restore)
        waitUntil("Restore left the control disabled") { self.button(AccessibilityID.FullGame.restore).isEnabled }
        assertExists(AccessibilityID.FullGame.options)
        try await session.setSimulatedError(nil, forAPI: .appStoreSync)
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
    }
}
