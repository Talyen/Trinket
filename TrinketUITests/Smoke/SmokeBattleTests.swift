import XCTest

final class SmokeBattleTests: TrinketUITestCase {
    func testBattleLaunchScreenStartsStageOneOne() {
        launchApp(arguments: TestLaunchArg.allForBattle())
        assertExists("Battle Pause Button")
    }
}
