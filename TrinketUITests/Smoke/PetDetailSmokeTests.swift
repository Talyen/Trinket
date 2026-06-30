import XCTest

final class SmokePetDetailTests: TrinketUITestCase {
    func testWolfPetDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("pet:wolf"))
        assertExists("Wolf detail hero header")
        assertExists("Stats")
        assertExists("Health")
    }

    func testBearPetDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("pet:bear"))
        assertExists("Bear detail hero header")
        assertExists("Stats")
        assertExists("Health")
    }
}
