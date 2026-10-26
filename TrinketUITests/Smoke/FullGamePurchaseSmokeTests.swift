import TrinketContent
import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseSmokeTests: FullGameStoreKitUITestCase {
    func testCampaignAndOptionsPurchaseUnlockRecruitedWarlock() throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        let freeStages = GameContent.chapters.filter { $0.number <= 3 }.flatMap { $0.stages.map(\.id) }
        launchApp(arguments: TestLaunchArg.allForTab("play") + TestLaunchArg.completedStages(freeStages))
        play.openCampaign(number: 4)
        let unlock = AccessibilityID.Play.stageAction(chapter: 4, stage: 1)
        tapButtonAfterScroll(unlock)
        dismissSheet(AccessibilityID.FullGame.offer)
        assertExists(unlock)

        tabBar.select(.options)
        openOptionsOffer()
        tapButton(AccessibilityID.FullGame.purchase)
        assertDoesNotExist(AccessibilityID.FullGame.offer, timeout: 10)
        assertDoesNotExist(AccessibilityID.FullGame.options, timeout: 10)
        assertDoesNotExist(AccessibilityID.FullGame.restore)
        assertWarlockAccessible()
        tapButton(AccessibilityID.CombatantDetail.collectionCard(name: "Warlock"))
        combatantDetail.assertLoaded(for: "Warlock")
        dismissSheet(AccessibilityID.CombatantDetail.header(name: "Warlock"))
        tabBar.select(.play)
        play.assertCampaignLoaded(number: 4)
        play.startBattle(chapter: 4, stage: 1)
        battle.assertActive()
    }
}
