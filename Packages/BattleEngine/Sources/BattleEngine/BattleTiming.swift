import Foundation

/// Shared battle timing constants. Durations advance once per combat round
/// (player turn + enemy turn); call sites still use the historical `ticks` name.
public enum BattleTiming {
    public static let deathsDoorDurationTicks = 8

    public static func remainingDurationLabel(ticks: Int) -> String {
        ticks == 1 ? "1 turn left" : "\(ticks) turns left"
    }
}
