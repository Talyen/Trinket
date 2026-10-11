import TrinketFeatureSupport
import XCTest

final class ExplorePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testLabyrinth() throws {
        try XCTSkipUnless(selected("labyrinth-scroll"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg
                .performanceArguments(from: TestLaunchArg.allForScreen("labyrinth-map")) + ["-performance-labyrinth-scroll"])
            waitUntil("Labyrinth must expose entry or its prepared map", timeout: 20) {
                self.button(AccessibilityID.Play.labyrinthEnter).exists
                    || self.any(AccessibilityID.Play.labyrinthMap).exists
            }
            if button(AccessibilityID.Play.labyrinthEnter).exists {
                tapButton(AccessibilityID.Play.labyrinthEnter)
            }
            assertExists(AccessibilityID.Play.labyrinthMap, timeout: 20)
            let labyrinthScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScroll = measured("labyrinth-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScroll {
                verifyScrollProbes(labyrinthScrollProbes, app.scrollViews.firstMatch)
            }
        }
    }
}
