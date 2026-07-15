import XCTest

final class SmokeBattleTests: SeededSmokeUITestCase {
    override var launchArguments: [String] {
        TestLaunchArg.allForBattle()
    }

    /// Load-only: deep-link opens stage 1-1 battle chrome.
    /// Mid-battle interactions live in `BattleFlowUITests` (Play-map entry).
    func testBattleLaunchScreenStartsStageOneOne() {
        battle.assertActive()
    }
}
