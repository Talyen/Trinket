import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    /// Canary: wallet + first category/row after the cinematic hero.
    func testHomesteadOverviewShowsWalletAndFirstCategory() {
        homestead.assertLoaded()
        assertExists(AccessibilityID.Homestead.resourceWallet)
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Farming"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Wheat Field"))
    }
}
