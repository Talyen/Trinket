import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayDashboardRenders() {
        launchApp(arguments: [TestLaunchArg.resetState])
        assertExists("Play")
        assertExists(app.staticTexts["Battle"])
    }

    func testHeroSelectionAppears() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.staticTexts["Battle"].tap()
        assertExists("Select Hero")
        assertExists("Knight selection card")
        assertExists("Wizard selection card")
        assertExists("Rogue selection card")
    }
}
