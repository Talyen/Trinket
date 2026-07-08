import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    /// Mid-battle interactions: enter via Play map (not `-launch-screen battle` + extreme ticks).
    func testMidBattleCombatantDetailAndTabPause() {
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("0.05", in: TestLaunchArg.testLaunchArgs))

        play.assertLoaded()
        play.openStage(chapter: 1, stage: 1)

        battle.assertActive()
        assertExists(AccessibilityID.CombatantDetail.battleCard(name: "Knight"))
        assertExists(AccessibilityID.CombatantDetail.battleCard(name: "Wolf"))

        // If Stage 1-1 already resolved, mid-battle chrome is gone — defer to the victory test.
        if battle.victory.waitForExistence(timeout: 1) {
            return
        }

        // Leave Play to pause the battle, then return and inspect a combatant.
        _ = battle.menu.waitForExistence(timeout: 2)
        tabBar.selectCollection()
        assertExists(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        tabBar.selectPlay()

        if battle.victory.waitForExistence(timeout: 1) {
            return
        }

        battle.assertActive(timeout: 2)
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
        battle.assertActive()

        assertExists(battle.victory, timeout: 60)

        assertExists(AccessibilityID.Battle.experience)
        assertExists(AccessibilityID.Battle.rewards)
        assertButtonExists(AccessibilityID.Battle.continueButton)

        battle.openMenu()
        battle.assertCombatLogVisible()
        battle.assertRetreatUnavailable()
    }
}
