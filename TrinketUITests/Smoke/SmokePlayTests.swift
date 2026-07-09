import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayScreenLoadsWithFirstStage() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))
    }

    func testModesEntryOpensAspectsHub() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.modesEntry)
        app.buttons[AccessibilityID.Play.modesEntry].tap()
        assertExists(AccessibilityID.Play.modesScreen)
        app.buttons[AccessibilityID.Play.aspectsModeCard].tap()
        assertExists(AccessibilityID.Play.aspectsHub)
        assertExists(AccessibilityID.Play.aspectRow("ironVein"))
    }
}
