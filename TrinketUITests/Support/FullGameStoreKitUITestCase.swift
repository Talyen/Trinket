import StoreKitTest
import Synchronization
import TrinketFeatureSupport
import XCTest

class FullGameStoreKitUITestCase: TrinketUITestCase {
    private static let registered = Mutex(false)

    private(set) var storeSession: SKTestSession?

    override func tearDownWithError() throws {
        defer {
            storeSession?.clearTransactions()
            storeSession = nil
        }
        try super.tearDownWithError()
    }

    func skipUnavailablePurchaseAutomation() throws {
        if ProcessInfo.processInfo.environment["TRINKET_REQUIRED_PURCHASE"] == "1" {
            XCTAssertFalse(
                ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
                    && ProcessInfo.processInfo.operatingSystemVersion.minorVersion == 5,
                "CI requires a runtime supporting the Full Game purchase journey",
            )
            return
        }
        try XCTSkipIf(
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
                && ProcessInfo.processInfo.operatingSystemVersion.minorVersion == 5,
            "StoreKit purchase UI automation is unavailable under iOS 26.5 xcodebuild tests.",
        )
    }

    func launchOptionsOffer(arguments: [String] = []) throws {
        try startStoreSession()
        // Recruitment is earned separately; the seed isolates paid content access.
        launchApp(arguments: TestLaunchArg.allForTab("options") + arguments)
        openOptionsOffer()
    }

    func openOptionsOffer() {
        tapButtonAfterScroll(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
    }

    func assertFullGameAccess(_ expected: Bool) {
        waitUntil("Full Game access must become \(expected)") {
            do { return try self.coverageReport()["fullGameAccess"] as? Bool == expected }
            catch { return false }
        }
    }

    func assertWarlockAccessible() {
        revealWarlock()
        let card = button(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
        waitUntil("Full Game must permit access to the recruited Warlock") {
            trinketOnMainActor {
                guard let snapshot = try? card.snapshot() else { return false }
                return snapshot.isEnabled && !snapshot.label.isEmpty && !snapshot.label.hasSuffix(", locked")
            }
        }
    }

    func revealWarlock() {
        let tab = tabBar.button(for: .collection)
        if !tab.isSelected {
            tapWhenReady(tab)
        }
        let card = AccessibilityID.CombatantDetail.collectionCard(name: "Warlock")
        if !button(card).exists {
            tapButton(AccessibilityID.Collection.heroesCategory)
        }
        reveal(button(card))
    }

    func assertPurchaseProductLoaded() {
        XCTAssertTrue(waitForProductLoaded(timeout: 8), "Full Game purchase product did not load")
    }

    func startStoreSession() throws {
        // Registration belongs to this runner process; sessions and transactions remain per-test.
        let needsRegistration = Self.registered.withLock { !$0 }
        if needsRegistration {
            launchApp(arguments: TestLaunchArg.allForTab("options"), waitForPreparation: false)
            app.terminate()
        }
        let session = try SKTestSession(configurationFileNamed: "Trinket")
        Self.registered.withLock { $0 = true }
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        storeSession = session
    }

    private func waitForProductLoaded(timeout: TimeInterval) -> Bool {
        let purchase = button(AccessibilityID.FullGame.purchase)
        let retry = button(AccessibilityID.FullGame.retry)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            guard trinketWaitUntil(timeout: max(0, deadline.timeIntervalSinceNow), condition: {
                purchase.exists || retry.exists
            }) else { return false }
            if purchase.exists {
                return true
            }
            tapWhenReady(retry)
        }
        return false
    }
}
