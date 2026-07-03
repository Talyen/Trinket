import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testBattleFlowAndCombatLoops() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.openStage("Stage 1-1 Node")

        assertButtonExists("Battle Pause Button")
        assertExists("Knight card")
        assertExists("Wolf card")
        assertExists("Battle Menu")

        tabBar.selectCollection()
        assertExists("Knight collection card")
        tabBar.selectPlay()

        assertButtonExists("Battle Pause Button", timeout: 3)

        button("Knight card").tap()
        let knightHeader = combatantDetail.header(for: "Knight")
        assertExists(knightHeader)
        XCTAssertEqual(knightHeader.label, "Knight, Hero, level 2, 35 of 120 experience")
        assertCombatantDetailSections()
        dismissSheet()

        assertExists("Victory", timeout: 12)

        assertExists("Experience")
        assertExists("Rewards")
        assertButtonExists("Continue Button")

        button("Battle Menu").tap()
        assertExists("Combat Log")
        XCTAssertFalse(button("Retreat").exists)
    }
}
