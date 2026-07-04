import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testBattleFlowAndCombatLoops() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        play.openStage("Stage 1-1 Node")

        assertButtonExists("Battle Pause Button")
        assertExists("Knight card")
        assertExists("Wolf card")

        let victory = any("Victory")
        if !victory.waitForExistence(timeout: 1) {
            _ = any("Battle Menu").waitForExistence(timeout: 2)
            tabBar.selectCollection()
            assertExists("Knight collection card")
            tabBar.selectPlay()

            if button("Battle Pause Button").waitForExistence(timeout: 3) {
                button("Knight card").tap()
                let knightHeader = combatantDetail.header(for: "Knight")
                assertExists(knightHeader)
                XCTAssertEqual(knightHeader.label, "Knight, Hero, level 2, 35 of 155 experience")
                assertCombatantDetailSections()
                dismissSheet()
            }
        }

        assertExists(victory, timeout: 30)

        assertExists("Experience")
        assertExists("Rewards")
        assertButtonExists("Continue Button")

        button("Battle Menu").tap()
        assertExists("Combat Log")
        XCTAssertFalse(button("Retreat").exists)
    }
}
