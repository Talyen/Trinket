import TrinketFeatureSupport
import XCTest

final class ExplorePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testLabyrinth() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg
                .performanceArguments(from: TestLaunchArg.allForScreen("labyrinth-map")) + ["-performance-labyrinth-scroll"])
            if button(AccessibilityID.Play.labyrinthEnter).trinketWaitForExistence(timeout: 3) {
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
