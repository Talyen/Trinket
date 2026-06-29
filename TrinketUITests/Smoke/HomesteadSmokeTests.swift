import XCTest

final class SmokeHomesteadTests: TrinketUITestCase {
    func testHomesteadTabExists() {
        launchApp(arguments: [TestLaunchArg.resetState])
        app.tabBars.buttons["Homestead"].tap()
        assertExists("Homestead")
    }
}
