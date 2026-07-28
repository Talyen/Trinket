import TrinketFeatureSupport
import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    /// Canary: Homestead shell entry — wallet on the overview.
    func testHomesteadOverviewShowsWalletAndFirstCategory() {
        homestead.assertLoaded()
        assertExists(AccessibilityID.Homestead.resourceWallet)
    }
}
