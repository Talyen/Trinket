import TrinketFeatureSupport
import XCTest

final class OutcomePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testChapterProgression() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance()
                + TestLaunchArg.completedStages((1 ... 9).map { "chapter-1-stage-\($0)" })
                + ["-performance-strong-party", "-performance-outcome-victory"])
            play.openCampaign()
            reveal(button(AccessibilityID.Play.stageAction(chapter: 1, stage: 10)))
            tapButton(AccessibilityID.Play.stageAction(chapter: 1, stage: 10))
            battle.assertActive()
            battle.autoBattleToggle.tap()
            assertExists(AccessibilityID.Battle.victory, timeout: 30)
            reveal(button(AccessibilityID.Battle.continueButton))
            measured("campaign-chapter-progression", iteration: iteration) {
                tapButton(AccessibilityID.Battle.continueButton)
                play.assertCampaignLoaded(number: 2)
            }
        }
    }

    @MainActor
    func testVictoryReveal() {
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
    func testDefeatReveal() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded() + TestLaunchArg.screen("battle"))
                + ["-performance-outcome-defeat", "-battle-performance-scenario", "turn-transition"])
            battle.assertActive()
            tapButton(AccessibilityID.Debug.battlePerformanceStart)
            waitForMeasurementState("measuring")
            assertExists(AccessibilityID.Battle.defeat, timeout: 30)
            finishMeasurement("defeat-reveal", iteration: iteration, settle: 3)
        }
    }

    @MainActor
    func testVictoryReturn() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("battle-victory")))
            assertExists(AccessibilityID.Battle.victory)
            assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
            measured("victory-claim-return", iteration: iteration) {
                tapButton(AccessibilityID.Battle.continueButton)
                play.assertCampaignLoaded()
            }
        }
    }

    @MainActor
    func testDefeatRetry() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg
                .performanceArguments(from: TestLaunchArg.allUnseeded() + TestLaunchArg.screen("battle-defeat")))
            assertExists(AccessibilityID.Battle.defeat)
            measured("defeat-retry", iteration: iteration) {
                tapButton(AccessibilityID.Battle.defeatPrimaryButton)
                battle.assertActive()
            }
        }
    }

    @MainActor
    func testDefeatRecovery() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg
                .performanceArguments(from: TestLaunchArg.allUnseeded() + TestLaunchArg.screen("battle-defeat-save-failure")))
            assertExists(AccessibilityID.Battle.defeat)
            measured("defeat-save-recovery", iteration: iteration) {
                tapButton(AccessibilityID.Battle.defeatLeaveButton)
                play.assertCampaignLoaded()
                XCTAssertFalse(app.alerts.firstMatch.exists)
            }
        }
    }

    @MainActor
    func testTalentReward() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance() + ["-performance-talent-reward", "-performance-outcome-victory"])
            play.openCampaign()
            play.startBattle(chapter: 1, stage: 1)
            battle.autoBattleToggle.tap()
            assertExists(AccessibilityID.Battle.victory, timeout: 30)
            reveal(button(AccessibilityID.Battle.continueButton))
            measured("postbattle-talent-reveal", iteration: iteration) {
                tapButton(AccessibilityID.Battle.continueButton)
                assertExists(AccessibilityID.TalentChoice.screen)
            }
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
