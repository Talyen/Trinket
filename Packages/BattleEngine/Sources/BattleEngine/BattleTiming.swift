import Foundation

/// Shared battle timing constants. Durations advance once per combat round
/// (player turn + enemy turn).
public enum BattleTiming {
    public static let deathsDoorDurationTurns = 8

    /// Turns left on a full stun/freeze meter after its action skip is consumed.
    ///
    /// Set to 2 because `EffectTurnEngine.advanceAll` runs in the same `endTurn`
    /// as consume: one tick happens immediately, and the second tick keeps the
    /// Stunned/Frozen status through the following player turn.
    public static let controlStatusLingerTurns = 2

    public static func remainingDurationLabel(turns: Int) -> String {
        turns == 1 ? "1 turn left" : "\(turns) turns left"
    }
}
