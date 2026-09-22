import TrinketContent
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseSmokeTests: FullGameStoreKitUITestCase {
    func testPurchaseUnlocksWarlockDetail() throws {
        try skipUnavailablePurchaseAutomation()
        try launchAndAwaitOfferProduct(arguments: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"]) {
            assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
            tapButton(AccessibilityID.FullGame.options)
        }
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 20)
        assertDoesNotExist(AccessibilityID.FullGame.options, timeout: 10)

        tabBar.selectCollection()
        tapButton(AccessibilityID.Collection.heroesCategory)
        let warlock = AccessibilityID.CombatantDetail.collectionCard(name: "Warlock")
        assertExistsAfterScroll(warlock, requireHittable: true)
        tapButton(warlock)
        combatantDetail.assertLoaded(for: "Warlock")
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
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 10)
        assertExists(unlock)
    }
}
