import XCTest

final class SmokeHomesteadTests: TrinketUITestCase {
    func testHomesteadTabExists() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        app.tabBars.buttons["Homestead"].tap()
        assertExists("Homestead")
    }
}
