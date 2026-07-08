import XCTest

final class SmokePlayTests: TrinketUITestCase {
    func testPlayScreenLoadsWithFirstStage() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)

        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))
    }
}
