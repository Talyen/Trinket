import Foundation
import TrinketCore

public struct ActionSpeed: Hashable {
    public var baseIntervalTicks: Int
    public var intervalModifier: Int = 0

    public var effectiveInterval: Int {
        max(1, baseIntervalTicks + intervalModifier)
    }
}

public enum BattleTiming {
    /// One battle tick equals one second of player-facing duration.
    public static let secondsPerTick = 1
    public static let heroActionIntervalTicks = 2
    public static let petActionIntervalTicks = 2
    public static let enemyActionIntervalTicks = 6
    public static let deathsDoorDurationTicks = 8

    public static func remainingDurationLabel(ticks: Int) -> String {
        let seconds = ticks * secondsPerTick
        return seconds == 1 ? "1 second left" : "\(seconds) seconds left"
    }
}
