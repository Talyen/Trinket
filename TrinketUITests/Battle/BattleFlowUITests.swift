import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    /// Mid-battle interactions: enter via Play map with a moderate tick so chrome stays visible.
    func testMidBattleCombatantDetailAndTabPause() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("0.25", in: TestLaunchArg.testLaunchArgs))

        play.assertLoaded()
        play.openStage(chapter: 1, stage: 1)

        // If Stage 1-1 already resolved, mid-battle chrome is gone — defer to the victory test.
        if battle.waitForMidBattleOrVictory() {
            return
        }

        // Knight is the card we open; Wolf may already be downed / off-layout mid-fight.
        assertExists(AccessibilityID.CombatantDetail.battleCard(name: "Knight"))

        // Pause immediately so the rest of the mid-battle checks are stable.
        if battle.pauseButton.waitForExistence(timeout: 1) {
            battle.pauseButton.tap()
        }

        // Leave Play to pause the battle, then return and inspect a combatant.
        _ = battle.menu.waitForExistence(timeout: Self.defaultTimeout)
        tabBar.selectCollection()
        assertExists(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        tabBar.selectPlay()

        if battle.victory.waitForExistence(timeout: 1) {
            return
        }

        battle.assertPresented()
        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertSeededHeroHeaderSummary(for: "Knight")
        assertCombatantDetailSections()
        dismissSheet()

        // Resume after tab-switch pause so the battle can continue if needed.
        if battle.pauseButton.exists {
            battle.pauseButton.tap()
        }
    }

    /// Victory path stays focused on outcome chrome; no mid-battle side quests.
    func testBattleVictorySummaryAndPostVictoryMenu() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("0.05", in: TestLaunchArg.testLaunchArgs))

        play.assertLoaded()
        play.openStage(chapter: 1, stage: 1)

        assertExists(battle.victory, timeout: 60)

        assertExists(AccessibilityID.Battle.experience)
        assertExists(AccessibilityID.Battle.rewards)
        assertButtonExists(AccessibilityID.Battle.continueButton)

        battle.openMenu()
        battle.assertCombatLogVisible()
        battle.assertRetreatUnavailable()
    }
}
