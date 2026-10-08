import Foundation
import StoreKit
import StoreKitTest
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseUITests: FullGameStoreKitUITestCase {
    func testExistingPurchaseUnlocksContentOnColdLaunch() throws {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        app.terminate()
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
