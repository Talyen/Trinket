import XCTest

final class SmokeHeroDetailTests: TrinketUITestCase {
    func testKnightHeroDetail() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")
        assertCombatantDetailSections()
        assertExists("Oathbound")
        assertExists(AccessibilityID.CombatantDetail.traitDescription)
        assertExists("Unlocks at Level 6")

        let header = combatantDetail.header(for: "Knight")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(header.exists, "Hero header should still exist after overscroll")
    }

    func testRogueHeroDetailLaunchScreenOpensDetail() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:rogue"))
        combatantDetail.assertLoaded(for: "Rogue")
        assertExists("Rogue")
    }
}
