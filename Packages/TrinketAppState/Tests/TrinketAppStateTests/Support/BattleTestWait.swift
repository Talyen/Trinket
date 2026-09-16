import Foundation
@testable import TrinketAppState

/// Shared waiter for battle-settlement retry paths.
///
/// Retry tests today poll with ad-hoc `Task.sleep(10ms)` loops (up to 3s).
/// New tests should use this helper so timeout and cadence live in one place;
/// existing loops migrate as they are touched.
@MainActor
enum BattleTestWait {
    /// Polls until `play.battle.activeBattle` clears or `timeout` elapses.
    /// Returns true when the battle settled in time.
    static func untilNoActiveBattle(
        in play: PlaySession,
        timeout: Duration = .seconds(3),
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while play.battle.activeBattle != nil, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return play.battle.activeBattle == nil
    }
}
