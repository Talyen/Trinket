import XCTest

final class LaunchScreenUITests: TrinketUITestCase {
    func testHeroDetailLaunchScreenOpensDetail() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:rogue"))

        assertExists("Rogue detail hero header")
        assertExists("Rogue")
    }
}
