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
        assertExists("Paladin selection card")
        assertExists("Mage selection card")
        assertExists("Rogue selection card")
    }
}
