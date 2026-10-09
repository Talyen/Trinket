import Foundation
import StoreKit
import StoreKitTest
import TrinketAppState
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

    func testAskToBuyApprovalWhileActiveUnlocksEarnedCharacter() throws {
        try verifyDeferredApproval(relaunch: false)
    }

    func testAskToBuyApprovalWhileTerminatedIsRecognizedOnRelaunch() throws {
        try verifyDeferredApproval(relaunch: true)
    }

    func testDeclinedAskToBuyRemainsLockedAndAllowsAnotherPurchase() throws {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer()
        let session = try XCTUnwrap(storeSession)
        session.askToBuyEnabled = true
        tapButton(AccessibilityID.FullGame.purchase)
        let pending = try pendingTransaction(in: session)
        tapButton(AccessibilityID.FullGame.close)
        try session.declineAskToBuyTransaction(identifier: pending.identifier)
        waitUntil("Decline must clear its pending transaction") {
            !session.allTransactions().contains { $0.pendingAskToBuyConfirmation }
        }
        assertWarlockLocked()
        session.askToBuyEnabled = false
        tabBar.selectOptions()
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
    }

    @MainActor
    func testCancelledPurchaseAllowsRetryWithoutUnlocking() async throws {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer()
        let session = try XCTUnwrap(storeSession)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        tapButton(AccessibilityID.FullGame.purchase)
        waitUntil("Cancelled purchase must leave purchase available") {
            self.button(AccessibilityID.FullGame.purchase).isEnabled
        }
        XCTAssertTrue(session.allTransactions().isEmpty)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        tapButton(AccessibilityID.FullGame.close)
        assertWarlockLocked()
        tabBar.selectOptions()
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
    }

    @MainActor
    func testRestorePreservesPopulatedLocalProgress() async throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let session = try XCTUnwrap(storeSession)
        launchApp(arguments: TestLaunchArg.allForTab("play")
            + TestLaunchArg.completedStages(["chapter-1-stage-1"]))
        play.openCampaign()
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
        app.terminate()
        let transaction = try await session.buyProduct(identifier: FullGameStore.productID)
        XCTAssertTrue(session.allTransactions().contains { $0.identifier == UInt(transaction.id) })
        // Verification failure establishes locked access before Restore. An
        // already-unlocked cold launch would not prove restoration.
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        relaunchApp(arguments: ["-selectedTab", "options"])
        assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
        try await session.setSimulatedError(nil, forAPI: .verification)
        tapButton(AccessibilityID.FullGame.restore)
        waitUntil("Restore must finish") { self.button(AccessibilityID.FullGame.restore).isEnabled }
        assertWarlockAccessible()
        tabBar.selectPlay()
        play.openCampaign()
        XCTAssertTrue(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 2)).isEnabled)
    }

    func testRefundRemovesAccessWithoutErasingEarnedProgress() throws {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
        let session = try XCTUnwrap(storeSession)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        waitUntil("Refund must be reflected in StoreKit") {
            session.allTransactions().contains { $0.identifier == transaction.identifier && $0.cancelDate != nil }
        }
        tabBar.selectOptions()
        assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
        assertWarlockLocked()
        relaunchApp(arguments: ["-selectedTab", "collection"])
        assertWarlockLocked()
        // Recruitment survives: repurchasing restores access to the same earned character.
        tabBar.selectOptions()
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
    }

    private func verifyDeferredApproval(relaunch: Bool) throws {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer()
        let session = try XCTUnwrap(storeSession)
        session.askToBuyEnabled = true
        tapButton(AccessibilityID.FullGame.purchase)
        let pending = try pendingTransaction(in: session)
        tapButton(AccessibilityID.FullGame.close)
        assertWarlockLocked()
        if relaunch {
            app.terminate()
        }
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        waitUntil("Approval must clear pending state") {
            session.allTransactions().contains { $0.identifier == pending.identifier && !$0.pendingAskToBuyConfirmation }
        }
        if relaunch {
            relaunchApp(arguments: ["-selectedTab", "collection"])
        }
        assertWarlockAccessible()
    }

    private func pendingTransaction(in session: SKTestSession) throws -> SKTestTransaction {
        waitUntil("Ask to Buy must create a deferred transaction") {
            session.allTransactions().contains { $0.pendingAskToBuyConfirmation }
        }
        return try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
    }

    private func assertWarlockLocked() {
        tabBar.selectCollection()
        tapButton(AccessibilityID.Collection.heroesCategory)
        let card = button(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
        scrollUntilVisible(card, swipingUp: true, requireHittable: true)
        XCTAssertTrue(card.label.hasSuffix(", locked"))
    }
}
