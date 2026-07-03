import XCTest

final class SmokePetDetailTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForScreen("pet:wolf")
    }

    func testWolfPetDetailRenders() {
        combatantDetail.assertLoaded(for: "Wolf")
        assertCombatantDetailSections()
    }
}
