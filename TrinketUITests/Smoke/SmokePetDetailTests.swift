import XCTest

final class SmokePetDetailTests: SeededSmokeUITestCase {
    override class var launchArguments: [String] {
        TestLaunchArg.allForScreen("pet:wolf")
    }

    func testWolfPetDetailRenders() {
        combatantDetail.assertLoaded(for: "Wolf")
        assertCombatantDetailSections()
    }
}
