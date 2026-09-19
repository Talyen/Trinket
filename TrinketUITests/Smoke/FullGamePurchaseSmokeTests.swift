import StoreKitTest
import TrinketContent
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseSmokeTests: TrinketUITestCase {
    private var storeSession: SKTestSession?

    override func setUpWithError() throws {
        try super.setUpWithError()
        let session = try SKTestSession(configurationFileNamed: "Trinket")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        storeSession = session
    }

    override func tearDownWithError() throws {
        storeSession?.clearTransactions()
        storeSession = nil
        try super.tearDownWithError()
    }

    func testOfferDismissalAndReopen() throws {
        try throwIfStoreKitPurchaseUnavailable()
        try launchAndAwaitOfferProduct(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"]) { file, line in
            assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true, file: file, line: line)
            tapButton(AccessibilityID.FullGame.options, file: file, line: line)
        }
        attachSuccessScreenshot(named: "Full Game offer")
        dismissSheet()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 10))
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
    }

    func testAskToBuyPurchaseRestoreAndRepurchase() throws {
        try throwIfStoreKitPurchaseUnavailable()
        try launchAndAwaitOfferProduct(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"]) { file, line in
            assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true, file: file, line: line)
            tapButton(AccessibilityID.FullGame.options, file: file, line: line)
        }
        let session = try XCTUnwrap(storeSession)
        session.askToBuyEnabled = true
        tapButton(AccessibilityID.FullGame.purchase)
        assertExists(AccessibilityID.FullGame.status, timeout: 20)
        let pending = try XCTUnwrap(session.allTransactions().first)
        XCTAssertEqual(pending.state, .deferred)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].exists)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        XCTAssertTrue(app.otherElements[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 20))
        session.askToBuyEnabled = false
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.options].waitForNonExistence(timeout: 10))
        assertExistsAfterScroll(AccessibilityID.FullGame.restore, requireHittable: true)
        tapButton(AccessibilityID.FullGame.restore)
        assertExists(AccessibilityID.FullGame.status, timeout: 20)
        let purchase = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: purchase.identifier)
        assertExists(AccessibilityID.FullGame.options, timeout: 20)
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
        tapButton(AccessibilityID.FullGame.purchase)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 20))
        let transactionCount = session.allTransactions().count
        XCTAssertEqual(transactionCount, 2)
    }

    func testGameplayResetReturnsToOnboarding() {
        launchApp(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"])
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressButton)
        app.alerts.buttons[AccessibilityID.Options.resetProgressConfirmation].tap()
        assertExists(AccessibilityID.Onboarding.heroScreen, timeout: 20)
    }

    private func throwIfStoreKitPurchaseUnavailable() throws {
        try XCTSkipIf(
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26
                && ProcessInfo.processInfo.operatingSystemVersion.minorVersion == 5,
            "StoreKit purchase UI automation is unavailable under iOS 26.5 xcodebuild tests.",
        )
    }

    private func assertPurchaseProductLoaded(
        timeout: TimeInterval = 20,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        guard waitForProductLoaded(timeout: timeout) else {
            fail("Button '\(AccessibilityID.FullGame.purchase)' not found after retrying", file: file, line: line)
            return
        }
    }

    /// Opens the Full Game offer and waits for the purchasable product.
    ///
    /// When the product catalog never resolves, the test session itself is
    /// torn down and recreated around a relaunch before failing. Under
    /// Xcode 27 StoreKitTest the catalog can fail to resolve for the
    /// lifetime of the first session on a fresh install (every session call
    /// errors); a new session plus a settled install then resolves
    /// immediately, matching what the next test run would observe. Only the
    /// failure path pays for the second launch.
    private func launchAndAwaitOfferProduct(
        arguments: [String],
        file: StaticString = #file,
        line: UInt = #line,
        open: (_ file: StaticString, _ line: UInt) -> Void,
    ) throws {
        launchApp(arguments: arguments)
        open(file, line)
        assertExists(AccessibilityID.FullGame.offer, file: file, line: line)
        if waitForProductLoaded(timeout: 20) {
            return
        }
        storeSession?.clearTransactions()
        storeSession = nil
        app.terminate()
        let session = try SKTestSession(configurationFileNamed: "Trinket")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        session.clearTransactions()
        storeSession = session
        launchApp(arguments: arguments)
        open(file, line)
        assertExists(AccessibilityID.FullGame.offer, file: file, line: line)
        assertPurchaseProductLoaded(file: file, line: line)
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

    func testLockedCharactersOpenOfferAndReturnToCollection() {
        launchApp(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "collection"])
        let characters = [
            (AccessibilityID.Collection.heroesCategory, "Warlock"),
            (AccessibilityID.Collection.companionsCategory, "Phoenix"),
        ]
        for (category, name) in characters {
            assertExistsAfterScroll(category, requireHittable: true)
            tapButton(category)
            let card = AccessibilityID.CombatantDetail.collectionCard(name: name)
            assertExistsAfterScroll(card, requireHittable: true)
            tapButton(card)
            assertExists(AccessibilityID.FullGame.offer)
            XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.CombatantDetail.header(name: name)].exists)
            attachSuccessScreenshot(named: "Full Game offer - \(name)")
            dismissSheet()
            XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 10))
            assertExists(card)
            XCTAssertFalse(app.descendants(matching: .any)[AccessibilityID.CombatantDetail.header(name: name)].exists)
            goBack()
        }
    }

    func testCampaignUnlockOffersTheNextChapter() {
        let freeStages = GameContent.chapters.filter { $0.number <= 3 }.flatMap { $0.stages.map(\.id) }
        launchApp(arguments: TestLaunchArg.allUnseeded() + TestLaunchArg.completedStages(freeStages))
        tapButton(AccessibilityID.Play.campaignModeCard)
        let unlock = AccessibilityID.Play.stageAction(chapter: 4, stage: 1)
        assertExistsAfterScroll(unlock, requireHittable: true)
        tapButton(unlock)
        assertExists(AccessibilityID.FullGame.offer)
        dismissSheet()
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 10))
        assertExists(unlock)
    }
}
