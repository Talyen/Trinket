import TrinketFeatureSupport
import XCTest

final class BattleInteractionPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testBattleControls() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForMidBattle()))
            play.openCampaign()
            play.startBattle(chapter: 1, stage: 1)
            battle.assertActive()
            measured("battle-inspection", iteration: iteration) {
                battle.handCards.firstMatch.press(forDuration: 0.7)
                assertExists(AccessibilityID.Battle.abilityDetail)
                dismissSheet()
                assertDoesNotExist(AccessibilityID.Battle.abilityDetail)
                battle.openCombatantCard(named: "Knight")
                combatantDetail.assertLoaded(for: "Knight")
            }
            let detailScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            performScrollGestures(app.scrollViews.firstMatch)
            verifyScrollProbes(detailScrollProbes, app.scrollViews.firstMatch)
            dismissSheet()
            assertDoesNotExist(AccessibilityID.CombatantDetail.vitalBarsSection)
            measured("battle-auto", iteration: iteration, settle: 3) {
                let count = battle.handCards.count
                battle.autoBattleToggle.tap()
                let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count < %d", count), object: battle.handCards)
                XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
                battle.autoBattleToggle.tap()
            }
            measured("battle-retreat", iteration: iteration) {
                battle.openActions()
                battle.retreatAction.tap()
                battle.defeatLeaveAction.trinketTapWhenReady()
                play.assertCampaignLoaded()
            }
        }
    }

    @MainActor
    func testBattleLog() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.replacingBattleTickInterval(
                "60",
                in: TestLaunchArg.allForBattle(),
            )) + ["-performance-log"])
            battle.assertActive()
            measured("battle-log", iteration: iteration) {
                battle.openActions()
                tapButton(AccessibilityID.Battle.combatLog)
                assertExists(AccessibilityID.Battle.combatLogSheet)
            }
            let log = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
            let logScrollProbes = captureScrollProbes(log)
            let didScroll = measured("battle-log-scroll", iteration: iteration) {
                performScrollGestures(log)
            }
            if didScroll {
                verifyScrollProbes(logScrollProbes, log)
            }
            dismissSheet()
            assertDoesNotExist(AccessibilityID.Battle.combatLogSheet)
        }
    }
}
