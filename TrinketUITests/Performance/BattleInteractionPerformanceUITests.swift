import TrinketFeatureSupport
import XCTest

final class BattleInteractionPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testBattleLog() throws {
        try XCTSkipUnless(selected("battle-log-scroll"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.replacingBattleTickInterval(
                "60",
                in: TestLaunchArg.allForBattle(),
            )) + ["-performance-log"])
            battle.assertActive()
            battle.openActions()
            tapButton(AccessibilityID.Battle.combatLog)
            assertExists(AccessibilityID.Battle.combatLogSheet)
            let log = app.scrollViews[AccessibilityID.Battle.combatLogSheet]
            measured("battle-log-scroll", iteration: iteration, scrolling: log)
        }
    }
}
