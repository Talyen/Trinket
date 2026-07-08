import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    func testBattleLaunchScreenStartsStageOneOne() {
        assertButtonExists("Battle Pause Button")
    }
}
