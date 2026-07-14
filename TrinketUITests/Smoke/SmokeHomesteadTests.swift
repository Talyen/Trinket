import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    /// Canary: wallet + first category/row after the cinematic hero. Cross-category
    /// scroll coverage lives in `HomesteadFlowUITests`.
    func testHomesteadOverviewShowsWalletAndFirstCategory() {
        homestead.assertLoaded()
        assertExists(AccessibilityID.Homestead.resourceWallet)
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Farming"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Wheat Field"))
    }
}
