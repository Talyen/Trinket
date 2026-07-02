import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testBattleFlowAndCombatLoops() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.openStage("Stage 1-1 Node")
        assertButtonExists("Battle Button")
        button("Battle Button").tap()

        assertButtonExists("Battle Pause Button")

        assertExists("Knight card")
        assertExists("Wolf card")
        assertExists("Battle Menu")

        button("Knight card").tap()
        let knightHeader = combatantDetail.header(for: "Knight")
        assertExists(knightHeader)
        XCTAssertEqual(knightHeader.label, "Knight, Hero, level 2, 35 of 120 experience")
        assertCombatantDetailSections()
        dismissSheet()

        tabBar.selectCollection()
        assertExists("Knight")
        tabBar.selectPlay()

        assertExists("Victory", timeout: 15)

        assertExists("Experience")
        assertExists("Rewards")
        assertButtonExists("Continue Button")

        button("Battle Menu").tap()
        assertExists("Combat Log")
        XCTAssertFalse(button("Retreat").exists)
    }
}
