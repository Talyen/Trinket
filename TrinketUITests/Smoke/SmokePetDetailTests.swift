import XCTest

final class SmokePetDetailTests: TrinketUITestCase {
    func testWolfPetDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("pet:wolf"))
        combatantDetail.assertLoaded(for: "Wolf")
        assertCombatantDetailSections()
    }
}
