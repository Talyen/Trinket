import TrinketFeatureSupport
import XCTest

final class OutcomePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testVictoryReveal() throws {
        try XCTSkipUnless(selected("victory-reveal"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForBattle()) + ["-performance-outcome-victory"])
            battle.assertActive()
            measured("victory-reveal", iteration: iteration, settle: 3) {
                battle.autoBattleToggle.tap()
                assertExists(AccessibilityID.Battle.victory, timeout: 30)
            }
        }
    }

    @MainActor
    func testDefeatReveal() throws {
        try XCTSkipUnless(selected("defeat-reveal"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded() + TestLaunchArg.screen("battle"))
                + ["-performance-outcome-defeat", "-battle-performance-scenario", "turn-transition"])
            battle.assertActive()
            let stop = measurementControl
            tapButton(AccessibilityID.Debug.battlePerformanceStart)
            waitForMeasurementState("measuring")
            assertExists(AccessibilityID.Battle.defeat, timeout: 30)
            finishMeasurement("defeat-reveal", iteration: iteration, settle: 3, control: stop)
        }
    }

    @MainActor
    func testVictoryReturn() throws {
        try XCTSkipUnless(selected("victory-claim-return"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("battle-victory")))
            assertExists(AccessibilityID.Battle.victory)
            reveal(button(AccessibilityID.Battle.continueButton))
            measured("victory-claim-return", iteration: iteration) {
                tapButton(AccessibilityID.Battle.continueButton)
                play.assertCampaignLoaded()
            }
        }
    }

    @MainActor
    func testTalentReward() throws {
        try XCTSkipUnless(selected("postbattle-talent-reveal") || selected("postbattle-talent-choice"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance() + ["-performance-talent-reward", "-performance-outcome-victory"])
            play.openCampaign()
            play.startBattle(chapter: 1, stage: 1)
            tapWhenReady(battle.autoBattleToggle)
            assertExists(AccessibilityID.Battle.victory, timeout: 30)
            reveal(button(AccessibilityID.Battle.continueButton))
            measured("postbattle-talent-reveal", iteration: iteration) {
                tapButton(AccessibilityID.Battle.continueButton)
                assertExists(AccessibilityID.TalentChoice.screen)
            }
            guard selected("postbattle-talent-choice") else { continue }
            measured("postbattle-talent-choice", iteration: iteration) {
                let tree = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Post-Battle Talent Tree ")).firstMatch
                tapWhenReady(tree)
                let node = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "Post-Battle Talent Node ")).firstMatch
                tapWhenReady(node)
                reveal(button(AccessibilityID.TalentChoice.unlockButton))
                tapButton(AccessibilityID.TalentChoice.unlockButton)
                assertDoesNotExist(AccessibilityID.TalentChoice.unlockButton)
                play.assertCampaignLoaded()
            }
        }
    }
}
