import XCTest

final class SmokeHomesteadTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    func testHomesteadOverviewShowsWalletCategoriesAndRepresentativeRows() {
        homestead.assertLoaded()
        assertExists(AccessibilityID.Homestead.resourceWallet)
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Farming"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Wheat Field"))

        assertExistsAfterScroll(AccessibilityID.Homestead.category("Crafting"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Alchemy Lab"))
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Arcana"))
    }
}
