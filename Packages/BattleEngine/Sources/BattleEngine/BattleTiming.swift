import Foundation

public enum BattleTiming {
    public static let deathsDoorDurationTurns = 2

    public static let controlStatusLingerTurns = 2

    public static func remainingDurationLabel(turns: Int) -> String {
        turns == 1 ? "1 turn left" : "\(turns) turns left"
    }
}
