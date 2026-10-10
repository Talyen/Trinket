import TrinketContent
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseSmokeTests: FullGameStoreKitUITestCase {
    func testCampaignAndOptionsPurchaseUnlockRecruitedWarlock() throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let freeStages = GameContent.chapters.filter { $0.number <= 3 }.flatMap { $0.stages.map(\.id) }
        launchApp(arguments: TestLaunchArg.allForTab("play") + TestLaunchArg.completedStages(freeStages))
        tapButton(AccessibilityID.Play.campaignModeCard)
        let unlock = AccessibilityID.Play.stageAction(chapter: 4, stage: 1)
        assertExistsAfterScroll(unlock, requireHittable: true)
        tapButton(unlock)
        assertExists(AccessibilityID.FullGame.offer)
        dismissSheet(AccessibilityID.FullGame.offer)
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 10)
        assertExists(unlock)

        tabBar.selectOptions()
        openOptionsOffer()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 10)
        assertDoesNotExist(AccessibilityID.FullGame.options, timeout: 10)
        assertWarlockAccessible()
        tapButton(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
        combatantDetail.assertLoaded(for: "Warlock")
    }
}
