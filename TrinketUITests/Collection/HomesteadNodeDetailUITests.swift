import TrinketFeatureSupport
import XCTest

/// Homestead category → node → detail navigation is usable (CI-owned owner;
/// perf harness only exercises this as a side effect).
final class HomesteadNodeDetailUITests: TrinketUITestCase {
    func testHomesteadNodeDetailJourney() {
        launchApp(arguments: TestLaunchArg.allForTab("homestead"))
        homestead.assertLoaded()

        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        tapButton(AccessibilityID.Homestead.node(title: "Wheat Field"))
        homestead.assertNodeDetail(named: "Wheat Field")
    }
}
