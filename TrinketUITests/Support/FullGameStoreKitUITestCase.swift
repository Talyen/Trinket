import StoreKitTest
import TrinketFeatureSupport
import XCTest

class FullGameStoreKitUITestCase: TrinketUITestCase {
    private(set) var storeSession: SKTestSession?

    override func tearDownWithError() throws {
        storeSession?.clearTransactions()
        storeSession = nil
        try super.tearDownWithError()
    }

    func skipUnavailablePurchaseAutomation() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
                && ProcessInfo.processInfo.operatingSystemVersion.minorVersion == 5,
            "StoreKit purchase UI automation is unavailable under iOS 26.5 xcodebuild tests.",
        )
    }

    func launchAndAwaitOfferProduct(arguments: [String], open: () -> Void) throws {
        try startStoreSession()
        launchApp(arguments: arguments)
        open()
        assertExists(AccessibilityID.FullGame.offer)
        if waitForProductLoaded(timeout: 20) {
            return
        }

        // A fresh StoreKit session recovers a catalog that failed to resolve
        // throughout the first session on a new simulator install.
        storeSession?.clearTransactions()
        storeSession = nil
        app.terminate()
        try startStoreSession()
        launchApp(arguments: arguments)
        open()
        assertExists(AccessibilityID.FullGame.offer)
        XCTAssertTrue(waitForProductLoaded(timeout: 20), "Full Game purchase product did not load")
    }

    func assertPurchaseProductLoaded() {
        XCTAssertTrue(waitForProductLoaded(timeout: 20), "Full Game purchase product did not load")
    }

    func startStoreSession() throws {
        let session = try SKTestSession(configurationFileNamed: "Trinket")
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
            if waitForExistence(purchase, timeout: min(2, deadline.timeIntervalSinceNow)) {
                return true
            }
            guard waitForExistence(retry, timeout: min(1, max(0, deadline.timeIntervalSinceNow))) else {
                continue
            }
            tapWhenReady(retry)
        }
        return false
    }
}
