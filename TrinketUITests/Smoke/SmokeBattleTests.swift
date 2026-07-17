import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    /// Load-only: deep-link opens stage 1-1 battle chrome.
    /// Mid-battle hand drag lives in `testHandDragReleaseOnCombatantDoesNotOpenDetail`.
    func testBattleLaunchScreenStartsStageOneOne() {
        battle.assertActive()
    }

    /// Victory reward item opens the shared item detail sheet.
    func testVictoryRewardItemOpensDetail() {
        app.terminate()
        launchApp(arguments: TestLaunchArg.allForBattleVictory())

        assertExists(battle.victory, timeout: Self.defaultTimeout)
        assertButtonExists(AccessibilityID.Battle.continueButton)
        let rewardItemID = "chapter-1-stage-1-loot"
        tapButton(AccessibilityID.Battle.rewardItem(rewardItemID))
        assertExists(AccessibilityID.LoadoutPicker.itemDetail(rewardItemID), timeout: 8)
    }

    /// Hand drag onto a combatant must not open details; tap still works after.
    /// Uses mid-battle Play-map entry (not `-launch-screen battle`) so ticks do not race setup.
    /// Owns BattleHandView / prepared-art a11y regressions that pollute hand selectors.
    func testHandDragReleaseOnCombatantDoesNotOpenDetail() throws {
        app.terminate()
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; mid-battle chrome covered by victory test")
        }

        battle.assertActive()
        assertExists(battle.hand)

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Knight")]
        assertExists(hero)

        battle.hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        let detailHeader = combatantDetail.header(for: "Knight")
        XCTAssertFalse(
            detailHeader.waitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details"
        )

        if battle.victory.waitForExistence(timeout: 1) {
            throw XCTSkip("Battle resolved during hand-drag assertions; covered by victory test")
        }

        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertLoaded(for: "Knight")
    }
}
