import Foundation

/// Shared battle timing constants. Durations formerly measured in ticks now
/// advance once per combat round (player turn + enemy turn).
public enum BattleTiming {
    public static let deathsDoorDurationTurns = 8

    /// Legacy alias — numeric values are turns in the card combat model.
    public static let deathsDoorDurationTicks = deathsDoorDurationTurns

    public static func remainingDurationLabel(turns: Int) -> String {
        turns == 1 ? "1 turn left" : "\(turns) turns left"
    }

    /// Legacy entry point used by effect summaries; `ticks` means turns.
    public static func remainingDurationLabel(ticks: Int) -> String {
        remainingDurationLabel(turns: ticks)
    }
}
