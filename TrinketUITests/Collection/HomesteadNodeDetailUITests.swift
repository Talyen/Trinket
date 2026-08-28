import TrinketFeatureSupport
import XCTest

final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testHomesteadNodeDetailJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()

        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        homestead.assertNodeDetail(named: "Wheat Field")
    }
}
