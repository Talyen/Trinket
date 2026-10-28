import Foundation
import StoreKitTest
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseUITests: FullGameStoreKitUITestCase {
    @MainActor
    func testFailedRestoreKeepsContentLockedAndAllowsPurchase() async throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let session = try XCTUnwrap(storeSession)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        launchApp(arguments: TestLaunchArg.allForTab("options") + ["-coverage-diagnostics"])
        tapButtonAfterScroll(AccessibilityID.FullGame.restore)
        assertExists(AccessibilityID.FullGame.outcome)
        assertFullGameAccess(false)
        try await session.setSimulatedError(nil, forAPI: .appStoreSync)
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertFullGameAccess(true)
    }

    func testAskToBuyApprovalWhileActiveUpdatesAccessAndPurchaseControls() throws {
        let pending = try beginDeferredPurchase()
        try XCTUnwrap(storeSession).approveAskToBuyTransaction(identifier: pending.identifier)
        assertFullGameAccess(true)
        assertDoesNotExist(AccessibilityID.FullGame.options)
        assertDoesNotExist(AccessibilityID.FullGame.restore)
    }

    func testTerminatedApprovalRestoresAccessWithoutErasingLocalProgress() throws {
        let pending = try beginDeferredPurchase(arguments:
            TestLaunchArg.completedStages(["chapter-1-stage-1"]))
        let before = try coverageReport()
        let gold = try XCTUnwrap(before["gold"] as? Int)
        let completed = try XCTUnwrap(before["completedStages"] as? [String])
        XCTAssertTrue(completed.contains("chapter-1-stage-1"), "The recovery journey requires earned progress")
        app.terminate()
        try XCTUnwrap(storeSession).approveAskToBuyTransaction(identifier: pending.identifier)
        relaunchApp(arguments: ["-selectedTab", "options", "-coverage-diagnostics"])

        // Startup must recognize ownership without a Restore tap and retain this career.
        reveal(any(AccessibilityID.FullGame.status), requireHittable: false)
        assertDoesNotExist(AccessibilityID.FullGame.options)
        assertDoesNotExist(AccessibilityID.FullGame.restore)
        let after = try coverageReport()
        XCTAssertEqual(after["gold"] as? Int, gold)
        XCTAssertEqual(after["completedStages"] as? [String], completed)
        assertWarlockAccessible()
        tabBar.select(.play)
        play.openCampaign()
        tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 2))
        assertExists(AccessibilityID.Mystery.encounterTitle)
    }

    func testDeclinedAskToBuyRemainsLockedAndAllowsAnotherPurchase() throws {
        let pending = try beginDeferredPurchase()
        let session = try XCTUnwrap(storeSession)
        try session.declineAskToBuyTransaction(identifier: pending.identifier)
        assertFullGameAccess(false)
        revealWarlock()
        assertFullGameAccess(false)
        tapButton(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
        assertFullGameAccess(false)
        assertExists(AccessibilityID.FullGame.offer)
        session.askToBuyEnabled = false
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
    }

    func testRefundRemovesAccessWithoutErasingEarnedProgress() throws {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer(arguments: TestLaunchArg.completedStages(["chapter-1-stage-1"]) + ["-coverage-diagnostics"])
        let before = try coverageReport()
        let gold = try XCTUnwrap(before["gold"] as? Int)
        let completed = try XCTUnwrap(before["completedStages"] as? [String])
        XCTAssertTrue(completed.contains("chapter-1-stage-1"), "Refund recovery requires earned progress")
        tapButton(AccessibilityID.FullGame.purchase)
        // iOS 18's StoreKit test service can still be processing after the ordinary UI deadline.
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 60)
        assertFullGameAccess(true)
        let session = try XCTUnwrap(storeSession)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        assertFullGameAccess(false)
        reveal(button(AccessibilityID.FullGame.options))
        assertExists(AccessibilityID.FullGame.restore)
        relaunchApp(arguments: ["-selectedTab", "collection", "-coverage-diagnostics"])
        let after = try coverageReport()
        XCTAssertEqual(after["gold"] as? Int, gold, "Revocation must preserve earned Gold across relaunch")
        XCTAssertEqual(after["completedStages"] as? [String], completed, "Revocation must preserve Campaign progress")
        // Recruitment survives: repurchasing restores access to the same earned character.
        revealWarlock()
        tapButton(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
        assertExists(AccessibilityID.FullGame.offer)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer)
        assertWarlockAccessible()
    }

    private func beginDeferredPurchase(arguments: [String] = []) throws -> SKTestTransaction {
        try skipUnavailablePurchaseAutomation()
        try launchOptionsOffer(arguments: ["-coverage-diagnostics"] + arguments)
        let session = try XCTUnwrap(storeSession)
        session.askToBuyEnabled = true
        tapButton(AccessibilityID.FullGame.purchase)
        let pending = try pendingTransaction(in: session)
        // The test service can register a deferred transaction before the app
        // receives the purchase result. Keep the offer alive until it does.
        waitUntil("The app must receive the pending purchase result", timeout: 60) {
            (try? self.coverageReport()["fullGameOutcome"] as? String) == "pendingApproval"
        }
        dismissSheet(AccessibilityID.FullGame.offer)
        assertFullGameAccess(false)
        return pending
    }

    private func pendingTransaction(in session: SKTestSession) throws -> SKTestTransaction {
        var pending: SKTestTransaction?
        waitUntil("Ask to Buy must create a deferred transaction") {
            pending = session.allTransactions().first { $0.pendingAskToBuyConfirmation }
            return pending != nil
        }
        return try XCTUnwrap(pending)
    }
}
