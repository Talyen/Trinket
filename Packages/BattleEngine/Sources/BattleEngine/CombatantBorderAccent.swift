import Foundation
import TrinketCore

/// Picks the single keyword used for a combatant card's status border pulse.
///
/// At most one accent is shown. Priority favors Death's Door, then a triggered
/// Stun/Freeze. DoTs, build-up control meters, and common buffs are ignored.
public enum CombatantBorderAccent: Sendable {
    /// Highest-priority border keyword among `effects`, or `nil` when none qualify.
    ///
    /// - Parameter controlAccentRequiresPendingSkip: When `true` (party portraits),
    ///   only an unconsumed action skip paints Stun/Freeze. When `false` (enemies),
    ///   a full control meter including post-skip linger still accents so Shatter/
    ///   Dazed feedback remains readable.
    public static func keyword(
        from effects: [ActiveEffect],
        controlAccentRequiresPendingSkip: Bool = false
    ) -> Keyword? {
        if effects.contains(where: { $0.effect.kind == .deathsDoor }) {
            return .deathsDoor
        }
        if controlAccentRequiresPendingSkip {
            if let control = effects.first(where: \.isAwaitingActionSkip) {
                return control.keyword
            }
        } else if let control = effects.first(where: \.effect.isActionSkipPending) {
            return control.keyword
        }
        return nil
    }
}
