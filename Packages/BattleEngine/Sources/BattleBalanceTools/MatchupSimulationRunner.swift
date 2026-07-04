import Foundation
import BattleEngine
import TrinketCore
import TrinketContent

enum MatchupSimulationRunner {
    struct Result: Sendable {
        let winCount: Int
        let tickLimitCount: Int
        let runCount: Int
        let averageTickCount: Double
        let averageActionCount: Double
    }

    static let adaptiveMinimumRuns = 5

    static func run(
        _ configured: ConfiguredSimulationMatchup,
        runsPerMatchup: Int,
        maxTicks: Int,
        baseSeed: UInt64,
        matchupIndex: Int
    ) -> Result {
        var winCount = 0
        var tickLimitCount = 0
        var tickTotal = 0
        var actionTotal = 0
        var completedRuns = 0

        for runIndex in 0 ..< runsPerMatchup {
            let seed = baseSeed &+ UInt64(matchupIndex) &+ UInt64(runIndex) &+ 100_000
            let options = BalanceSweepRunner.sweepOptions(maxTicks: maxTicks, seed: seed)
            let result = BattleSimulator.run(configured, options: options)
            completedRuns += 1
            if result.didWin {
                winCount += 1
            }
            if result.didHitTickLimit {
                tickLimitCount += 1
            }
            tickTotal += result.tickCount
            actionTotal += result.actionCount

            if completedRuns >= adaptiveMinimumRuns,
               winCount == 0 || winCount == completedRuns {
                break
            }
        }

        return Result(
            winCount: winCount,
            tickLimitCount: tickLimitCount,
            runCount: completedRuns,
            averageTickCount: Double(tickTotal) / Double(completedRuns),
            averageActionCount: Double(actionTotal) / Double(completedRuns)
        )
    }
}
