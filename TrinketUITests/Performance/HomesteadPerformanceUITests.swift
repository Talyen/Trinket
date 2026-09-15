import TrinketFeatureSupport
import XCTest

final class HomesteadPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testBuild() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead") + ["-performance-homestead-build"])
            homestead.openFarmingCategoryAndRevealWheatFieldNode()
            tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
            homestead.assertNodeDetail(named: "Wheat Field")
            measured("homestead-build", iteration: iteration, settle: 3) {
                tapButton(AccessibilityID.Homestead.improveButton)
                assertExists(AccessibilityID.Homestead.upgradeSheet)
                tapButton(AccessibilityID.Homestead.upgradeButton)
                assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
                assertExists(AccessibilityID.Homestead.progress(tier: 1))
            }
        }
    }

    @MainActor
    func testHomestead() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead"))
            homestead.assertLoaded()
            let homesteadRootProbes = captureScrollProbes(app.scrollViews.firstMatch)
            measured("homestead-root-scroll", iteration: iteration) { performScrollGestures(app.scrollViews.firstMatch) }
            verifyScrollProbes(homesteadRootProbes, app.scrollViews.firstMatch)
            measured("homestead-category-browse", iteration: iteration) {
                homestead.openFarmingCategoryAndRevealWheatFieldNode()
                assertExists(AccessibilityID.Homestead.gallery)
            }
            let homesteadGalleryProbes = captureScrollProbes(app.scrollViews.firstMatch)
            measured("homestead-gallery-scroll", iteration: iteration) { performScrollGestures(app.scrollViews.firstMatch) }
            verifyScrollProbes(homesteadGalleryProbes, app.scrollViews.firstMatch)
            reveal(button(AccessibilityID.Homestead.node(title: "Wheat Field")))
            measured("homestead-improvement", iteration: iteration, settle: 3) {
                tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
                homestead.assertNodeDetail(named: "Wheat Field")
                tapButton(AccessibilityID.Homestead.improveButton)
                assertExists(AccessibilityID.Homestead.upgradeSheet)
                tapButton(AccessibilityID.Homestead.upgradeButton)
                assertDoesNotExist(AccessibilityID.Homestead.upgradeSheet)
                assertExists(AccessibilityID.Homestead.progress(tier: 2))
            }
            measured("homestead-wallet-return", iteration: iteration) {
                tapButton(AccessibilityID.Homestead.walletButton)
                assertExists(AccessibilityID.Homestead.resourceWallet)
                app.navigationBars.containing(.button, identifier: AccessibilityID.Homestead.closeSheetButton).firstMatch
                    .coordinate(withNormalizedOffset: CGVector(
                        dx: 0.5,
                        dy: 0.1,
                    ))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)))
                tapButton(AccessibilityID.Homestead.closeSheetButton)
                tapButton(AccessibilityID.Homestead.backButton)
                assertExists(AccessibilityID.Homestead.gallery)
            }
        }
    }

    @MainActor
    func testCollection() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "options"))
            scrollUntilVisible(button(AccessibilityID.Options.unlockAllButton), swipingUp: true, requireHittable: true)
            tapButton(AccessibilityID.Options.unlockAllButton)
            tabBar.selectHomestead()
            homestead.assertLoaded()
            measured("homestead-material-collection", iteration: iteration, settle: 3) {
                tapButton(AccessibilityID.Homestead.collectButton)
                assertDoesNotExist(AccessibilityID.Homestead.collectButton)
                tabBar.selectOptions()
                tabBar.selectHomestead()
                assertDoesNotExist(AccessibilityID.Homestead.collectButton)
            }
        }
    }
}
