import TrinketFeatureSupport
import XCTest

final class BattleInteractionPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testBattleLog() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.replacingBattleTickInterval(
                "60",
                in: TestLaunchArg.allForBattle(),
            )) + ["-performance-log"])
            battle.assertActive()
            battle.openActions()
            tapButton(AccessibilityID.Battle.combatLog)
            assertExists(AccessibilityID.Battle.combatLogSheet)
            let log = app.collectionViews.firstMatch.exists ? app.collectionViews.firstMatch : app.tables.firstMatch
            let logScrollProbes = captureScrollProbes(log)
            let didScroll = measured("battle-log-scroll", iteration: iteration) {
                performScrollGestures(log)
            }
            if didScroll {
                verifyScrollProbes(logScrollProbes, log)
            }
            dismissSheet(AccessibilityID.Battle.combatLogSheet)
            assertDoesNotExist(AccessibilityID.Battle.combatLogSheet)
        }
    }
}
