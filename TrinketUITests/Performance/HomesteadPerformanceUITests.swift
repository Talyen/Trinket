import TrinketFeatureSupport
import XCTest

final class HomesteadPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testHomestead() throws {
        try XCTSkipUnless(selected("homestead-gallery-scroll"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead"))
            homestead.assertLoaded()
            homestead.openFarmingCategoryAndRevealWheatFieldNode()
            assertExists(AccessibilityID.Homestead.gallery)
            measured("homestead-gallery-scroll", iteration: iteration, scrolling: app.scrollViews.firstMatch)
        }
    }
}
