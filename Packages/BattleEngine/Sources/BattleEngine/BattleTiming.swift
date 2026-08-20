import Foundation

/// Shared battle timing constants. Durations advance once per combat round
/// (player turn + enemy turn + end-of-round effect pass).
public enum BattleTiming {
    /// Rounds Death's Door stays on the combatant after it triggers.
    ///
    /// The effect is still active during the last of these end-of-round effect
    /// passes (including DoT damage). Expiry grace covers that same pass so a
    /// DoT cannot kill in the same moment the effect falls off; grace clears
    /// before the next player turn.
    public static let deathsDoorDurationTurns = 2

    /// Turns left on a full stun/freeze meter after its action skip is consumed.
    ///
    /// Set to 2 because `EffectTurnEngine.advanceAll` runs in the same `endTurn`
    /// as consume: one pass happens immediately, and the second pass keeps the
    /// Stunned/Frozen status through the following player turn.
    public static let controlStatusLingerTurns = 2

    public static func remainingDurationLabel(turns: Int) -> String {
        turns == 1 ? "1 turn left" : "\(turns) turns left"
    }
}
