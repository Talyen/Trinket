import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    func testBattleLaunchScreenStartsStageOneOne() {
        battle.assertActive()
    }
}
