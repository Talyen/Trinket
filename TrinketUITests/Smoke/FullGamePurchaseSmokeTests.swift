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

    func testOfferDismissalPurchaseAndGameplayReset() throws {
        launchApp(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"])
        let session = try XCTUnwrap(storeSession)
        session.askToBuyEnabled = true
        assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
        tapButton(AccessibilityID.FullGame.options)
        assertExists(AccessibilityID.FullGame.offer)
        assertPurchaseProductLoaded()
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Full Game offer"
        preview.lifetime = .keepAlways
        add(preview)
        tapButton(AccessibilityID.FullGame.close)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 10))
        tapButton(AccessibilityID.FullGame.options)
        assertPurchaseProductLoaded()
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
        assertExistsAfterScroll(AccessibilityID.Options.resetProgressButton, requireHittable: true)
        tapButton(AccessibilityID.Options.resetProgressButton)
        app.alerts.buttons[AccessibilityID.Options.resetProgressConfirmation].tap()
        assertExists(AccessibilityID.Onboarding.heroScreen, timeout: 20)
        let transactionCount = session.allTransactions().count
        XCTAssertEqual(transactionCount, 2)
    }

    private func assertPurchaseProductLoaded(
        timeout: TimeInterval = 20,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let purchase = button(AccessibilityID.FullGame.purchase)
        let retry = button(AccessibilityID.FullGame.retry)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if waitForExistence(purchase, timeout: min(2, deadline.timeIntervalSinceNow)) {
                return
            }
            guard waitForExistence(retry, timeout: min(1, max(0, deadline.timeIntervalSinceNow))) else {
                continue
            }
            tapWhenReady(retry)
        }

        fail("Button '\(AccessibilityID.FullGame.purchase)' not found after retrying", file: file, line: line)
    }

    func testNestedCharacterOfferReturnsToDetails() {
        launchApp(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "collection"])
        tapButton(AccessibilityID.Collection.heroesCategory)
        assertExistsAfterScroll(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"), requireHittable: true)
        tapButton(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
        assertExists(AccessibilityID.CombatantDetail.header(name: "Warlock"), timeout: 20)
        assertExistsAfterScroll(AccessibilityID.FullGame.boundary, requireHittable: true)
        tapButton(AccessibilityID.FullGame.boundary)
        assertExists(AccessibilityID.FullGame.offer)
        tapButton(AccessibilityID.FullGame.close)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 10))
        assertExists(AccessibilityID.CombatantDetail.header(name: "Warlock"))
    }

    func testCampaignBoundaryKeepsRewardsAndOffersTheNextChapter() {
        let freeStages = GameContent.chapters.filter { $0.number <= 3 }.flatMap { $0.stages.map(\.id) }
        launchApp(arguments: TestLaunchArg.allUnseeded() + TestLaunchArg.completedStages(freeStages))
        tapButton(AccessibilityID.Play.campaignModeCard)
        assertExistsAfterScroll(AccessibilityID.FullGame.boundary, requireHittable: true)
        tapButton(AccessibilityID.FullGame.boundary)
        assertExists(AccessibilityID.FullGame.offer)
        tapButton(AccessibilityID.FullGame.close)
        XCTAssertTrue(app.descendants(matching: .any)[AccessibilityID.FullGame.offer].waitForNonExistence(timeout: 10))
        assertExists(AccessibilityID.FullGame.boundary)
    }
}
