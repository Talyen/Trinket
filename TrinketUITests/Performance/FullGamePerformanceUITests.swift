import StoreKitTest
import TrinketContent
import TrinketFeatureSupport
import XCTest

final class FullGamePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testLockedCharacterAndUnlockOffer() throws {
        let session = try SKTestSession(configurationFileNamed: "Trinket")
        session.resetToDefaultState()
        session.clearTransactions()
        defer { session.clearTransactions() }
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded() + ["-selectedTab", "collection"]))
            tapButton(AccessibilityID.Collection.heroesCategory)
            reveal(button(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock")))
            measured("locked-character-offer", iteration: iteration) {
                tapButton(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
                assertExists(AccessibilityID.FullGame.offer)
                tapButton(AccessibilityID.FullGame.close)
                assertDoesNotExist(AccessibilityID.FullGame.offer)
                assertExists(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
            }
            let freeStages = GameContent.chapters.filter { $0.number <= 3 }.flatMap { $0.stages.map(\.id) }
            launchApp(arguments: TestLaunchArg
                .performanceArguments(from: TestLaunchArg.allUnseeded() + TestLaunchArg.completedStages(freeStages)))
            tapButton(AccessibilityID.Play.campaignModeCard)
            let unlock = AccessibilityID.Play.stageAction(chapter: 4, stage: 1)
            reveal(button(unlock))
            measured("campaign-unlock-offer", iteration: iteration) {
                tapButton(unlock)
                assertExists(AccessibilityID.FullGame.offer)
                tapButton(AccessibilityID.FullGame.close)
                assertDoesNotExist(AccessibilityID.FullGame.offer)
                assertExists(unlock)
            }
        }
    }

    @MainActor
    func testOfferAndPurchase() throws {
        let session = try SKTestSession(configurationFileNamed: "Trinket")
        session.resetToDefaultState()
        session.disableDialogs = true
        defer { session.clearTransactions() }
        for iteration in 1 ... repetitionCount {
            session.clearTransactions()
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"]))
            assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
            measured("full-game-offer", iteration: iteration) {
                tapButton(AccessibilityID.FullGame.options)
                assertExists(AccessibilityID.FullGame.offer)
                assertExists(AccessibilityID.FullGame.purchase, timeout: 20)
                tapButton(AccessibilityID.FullGame.close)
                assertDoesNotExist(AccessibilityID.FullGame.offer)
            }
            tapButton(AccessibilityID.FullGame.options)
            assertExists(AccessibilityID.FullGame.purchase, timeout: 20)
            measured("full-game-purchase", iteration: iteration) {
                tapButton(AccessibilityID.FullGame.purchase)
                assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 20)
                assertDoesNotExist(AccessibilityID.FullGame.options)
            }
            assertExistsAfterScroll(AccessibilityID.FullGame.restore, requireHittable: true)
            measured("full-game-restore", iteration: iteration) {
                tapButton(AccessibilityID.FullGame.restore)
                let restored = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "label == %@", "Full Game restored."),
                    object: any(AccessibilityID.FullGame.status),
                )
                XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 20), .completed)
            }
        }
    }
}
