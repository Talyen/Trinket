import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    /// Load-only: deep-link opens stage 1-1 battle chrome.
    /// Hand-drag safety lives in `BattleFlowUITests` only.
    func testBattleLaunchScreenStartsStageOneOne() {
        battle.assertActive()
    }
}
