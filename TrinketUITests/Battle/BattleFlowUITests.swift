import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    /// Mid-battle interactions: enter via Play map and assert turn-based chrome stays visible.
    func testMidBattleCombatantDetailAndHandChrome() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.startBattle(chapter: 1, stage: 1)

        // If Stage 1-1 already resolved, mid-battle chrome is gone — defer to the victory test.
        if battle.waitForMidBattleOrVictory() {
            return
        }

        // Knight is the card we open; Wolf may already be downed / off-layout mid-fight.
        assertExists(AccessibilityID.CombatantDetail.battleCard(name: "Knight"))

        // Turn-based chrome: hand should be present mid-battle.
        battle.assertActive()
        assertExists(AccessibilityID.Battle.hand)

        // Leave Play, then return and inspect a combatant.
        tabBar.selectCollection()
        assertExists(AccessibilityID.CombatantDetail.collectionCard(name: "Knight"))
        tabBar.selectPlay()

        if battle.victory.waitForExistence(timeout: 1) {
            return
        }

        battle.assertPresented()
        battle.assertActive()
        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertSeededHeroHeaderSummary(for: "Knight")
        assertCombatantDetailSections()
        dismissSheet()
    }

    /// Victory path deep-links to outcome chrome; Combat Log remains available under Options
    /// (tapping it returns to Play and presents the log over the battle).
    func testBattleVictorySummaryAndPostVictoryMenu() {
        launchApp(arguments: TestLaunchArg.allForBattleVictory())

        assertExists(battle.victory, timeout: Self.defaultTimeout)

        assertExists(AccessibilityID.Battle.experience)
        assertExists(AccessibilityID.Battle.rewards)
        assertButtonExists(AccessibilityID.Battle.continueButton)

        tabBar.selectOptions()
        options.assertLoaded()
        options.assertCombatLogVisible()
        options.assertRetreatUnavailable()
    }
}
