import TrinketFeatureSupport
import XCTest

final class HomesteadPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testHomestead() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead"))
            homestead.assertLoaded()
            homestead.openFarmingCategoryAndRevealWheatFieldNode()
            assertExists(AccessibilityID.Homestead.gallery)
            let homesteadGalleryProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScrollGallery = measured("homestead-gallery-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScrollGallery {
                verifyScrollProbes(homesteadGalleryProbes, app.scrollViews.firstMatch)
            }
        }
    }
}
