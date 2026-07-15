import XCTest

final class SmokeHeroDetailTests: TrinketUITestCase {
    /// Load + header preservation. Equip/ability journeys live in `TabNavigationUITests`.
    func testHeroDetailOverscrollHeaderPreservation() {
        launchApp(arguments: TestLaunchArg.allForScreen("hero:knight"))
        combatantDetail.assertLoaded(for: "Knight")

        let header = combatantDetail.header(for: "Knight")
        assertExists(header)

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        start.press(forDuration: 0.1, thenDragTo: end)

        XCTAssertTrue(header.exists, "Hero header should still exist after overscroll")
    }
}
