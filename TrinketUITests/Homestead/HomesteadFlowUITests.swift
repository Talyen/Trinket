import XCTest

final class HomesteadFlowUITests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForTab("homestead")
    }

    /// Exhaustive overview breadth: deeper categories sit below the cinematic hero
    /// and several project rows — kept out of the Homestead smoke canary.
    func testOverviewReachesCraftingAlchemyAndArcanaSections() {
        homestead.assertLoaded()
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Crafting"))
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Alchemy Lab"))
        assertExistsAfterScroll(AccessibilityID.Homestead.category("Arcana"))
    }
}
