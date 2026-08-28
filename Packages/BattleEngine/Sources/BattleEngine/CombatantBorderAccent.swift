import Foundation
import TrinketCore

public enum CombatantBorderAccent: Sendable {
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
