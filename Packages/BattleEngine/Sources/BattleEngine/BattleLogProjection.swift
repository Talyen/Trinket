import Foundation
import TrinketCore
import TrinketContent

/// Incremental combat-log cache derived from the append-only `ActionEvent` stream.
/// Optional on `BattleState` so simulations that do not need a log avoid allocating
/// or updating log entries during the hot loop.
public struct BattleLogProjection {
    public private(set) var entries: [LogEntry] = []
    private var loggedEventCount: Int = 0

    public init() {}

    /// Full reduce from the event stream.
    public static func entries(from events: [ActionEvent], matchup: BattleMatchup) -> [LogEntry] {
        BattleLogReducer.entries(from: events, matchup: matchup)
    }

    /// Brings `entries` in sync with `events`. No-op when already current.
    public mutating func sync(events: [ActionEvent], matchup: BattleMatchup) {
        guard loggedEventCount < events.count else {
            if loggedEventCount > events.count {
                rebuildFromScratch(events: events, matchup: matchup)
            }
            return
        }

        entries.append(contentsOf: BattleLogReducer.entries(
            from: events,
            startingAt: loggedEventCount,
            matchup: matchup
        ))
        loggedEventCount = events.count
    }

    public mutating func rebuildFromScratch(events: [ActionEvent], matchup: BattleMatchup) {
        entries = Self.entries(from: events, matchup: matchup)
        loggedEventCount = events.count
    }
}
