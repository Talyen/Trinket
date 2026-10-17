import Foundation

public enum BattleTiming {
    public static let deathsDoorDurationTurns = 2

    public static let controlStatusLingerTurns = 2

    static func remainingDurationResource(turns: Int) -> LocalizedStringResource {
        L10n.duration_remaining(turns)
    }
}
