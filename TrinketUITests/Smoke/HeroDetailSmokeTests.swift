import XCTest

final class SmokeHeroDetailTests: TrinketUITestCase {
    func testKnightHeroDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        assertExists("Knight detail hero header")
        assertExists("Stats")
        assertExists("Health")
    }

    func testWizardHeroDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:wizard"))
        assertExists("Wizard detail hero header")
        assertExists("Stats")
        assertExists("Health")
    }

    func testRogueHeroDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:rogue"))
        assertExists("Rogue detail hero header")
        assertExists("Stats")
        assertExists("Health")
    }
}
