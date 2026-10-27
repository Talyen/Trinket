import Foundation
import TrinketCore

public enum CombatantBorderAccent: Sendable {
    public static func keyword(
        from effects: [ActiveEffect],
        controlAccentRequiresPendingSkip: Bool = false,
    ) -> Keyword? {
        var control: Keyword?
        for active in effects {
            if active.effect.kind == .deathsDoor {
                return .deathsDoor
            }
            if control == nil, controlAccentRequiresPendingSkip ? active.isAwaitingActionSkip : active.effect.isActionSkipPending {
                control = active.keyword
            }
        }
        return control
    }
}
