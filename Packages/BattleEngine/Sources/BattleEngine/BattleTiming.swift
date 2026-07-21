import Foundation

/// Shared battle timing constants. Durations advance once per combat round
/// (player turn + enemy turn).
public enum BattleTiming {
    public static let deathsDoorDurationTurns = 8

    public static func remainingDurationLabel(turns: Int) -> String {
        turns == 1 ? "1 turn left" : "\(turns) turns left"
    }
}
