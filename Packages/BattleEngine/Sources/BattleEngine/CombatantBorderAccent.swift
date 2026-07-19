import Foundation
import TrinketCore

/// Picks the single keyword used for a combatant card's status border pulse.
///
/// At most one accent is shown. Priority favors Death's Door, then a triggered
/// Stun/Freeze. DoTs, build-up control meters, and common buffs are ignored.
public enum CombatantBorderAccent: Sendable {
    /// Highest-priority border keyword among `effects`, or `nil` when none qualify.
    public static func keyword(from effects: [ActiveEffect]) -> Keyword? {
        if effects.contains(where: { $0.effect.kind == .deathsDoor }) {
            return .deathsDoor
        }
        if let control = effects.first(where: \.effect.isActionSkipPending) {
            return control.keyword
        }
        return nil
    }
}
