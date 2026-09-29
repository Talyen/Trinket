import TrinketFeatureSupport
import XCTest

final class ShopPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testShop() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForShop()
                    + TestLaunchArg.completedStages((1 ... 7).map { "chapter-2-stage-\($0)" })
                    + ["-starting-gold", "200"]))
            assertExists(AccessibilityID.Shop.goldBalance)
            let shopScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScroll = measured("shop-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScroll {
                verifyScrollProbes(shopScrollProbes, app.scrollViews.firstMatch)
            }
        }
    }
}
