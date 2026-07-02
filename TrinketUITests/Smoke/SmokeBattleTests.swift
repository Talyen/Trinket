import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override class var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    func testBattleLaunchScreenStartsStageOneOne() {
        assertButtonExists("Battle Pause Button")
    }
}
