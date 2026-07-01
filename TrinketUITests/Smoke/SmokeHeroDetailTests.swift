import XCTest

final class SmokeHeroDetailTests: TrinketUITestCase {
    func testKnightHeroDetailRenders() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        assertExists("Knight detail hero header")
        assertExists("Stats")
        assertExists("Health")
    }

    func testKnightHeroDetailShowsLockedSkillUnlockLevel() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        assertExists("Unlocks at Level 3")
    }

    func testKnightHeroHeaderSurvivesScrollCycle() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        assertExists("Knight detail hero header")

        let header = app.descendants(matching: .any)["Knight detail hero header"]
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(header.exists, "Hero header should still exist after overscroll")
    }
}
