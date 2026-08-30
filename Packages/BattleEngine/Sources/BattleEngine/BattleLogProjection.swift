import Foundation
import TrinketContent
import TrinketCore

public struct BattleLogProjection {
    public private(set) var entries: [LogEntry] = []
    private var loggedEventCount: Int = 0

    public init() {}

    public static func entries(from events: [ActionEvent]) -> [LogEntry] {
        BattleLogReducer.entries(from: events)
    }

    public mutating func sync(events: [ActionEvent]) {
        guard loggedEventCount < events.count else {
            if loggedEventCount > events.count {
                rebuildFromScratch(events: events)
            }
            return
        }

        entries.append(contentsOf: BattleLogReducer.entries(
            from: events,
            startingAt: loggedEventCount,
        ))
        loggedEventCount = events.count
    }

    public mutating func rebuildFromScratch(events: [ActionEvent]) {
        entries = Self.entries(from: events)
        loggedEventCount = events.count
    }
}
