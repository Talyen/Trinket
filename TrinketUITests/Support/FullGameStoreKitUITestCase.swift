import StoreKitTest
import Synchronization
import TrinketFeatureSupport
import XCTest

class FullGameStoreKitUITestCase: TrinketUITestCase {
    private static let registered = Mutex(false)

    private(set) var storeSession: SKTestSession?

    override func tearDownWithError() throws {
        storeSession?.clearTransactions()
        storeSession = nil
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
        assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
        tapButton(AccessibilityID.FullGame.options)
        assertExists(AccessibilityID.FullGame.offer)
        assertPurchaseProductLoaded()
    }

    func assertWarlockAccessible() {
        revealWarlock()
        let card = AccessibilityID.CombatantDetail.collectionCard(name: "Warlock")
        waitUntil("Full Game must permit access to the recruited Warlock") {
            !self.button(card).label.hasSuffix(", locked")
        }
    }

    func revealWarlock() {
        let tab = app.tabBars.buttons[AccessibilityID.Tab.collection]
        if !tab.isSelected {
            tapWhenReady(tab)
        }
        let card = AccessibilityID.CombatantDetail.collectionCard(name: "Warlock")
        if !button(card).exists {
            tapButton(AccessibilityID.Collection.heroesCategory)
        }
        assertExistsAfterScroll(card, requireHittable: true)
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
