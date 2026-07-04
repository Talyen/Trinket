import Foundation
import TrinketCore
import TrinketContent

/// Adds bonus damage when the target is Marked, then consumes the mark.
package struct MarkedBonusStep: DamageStep {
    public static let stepName = "MarkedBonus"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.sourceActorID != nil else { return }
        guard let index = state.activeEffects.firstIndex(where: { if case .marked = $0.effect { return true }; return false }) else {
            return
        }

        let active = state.activeEffects[index]
        guard case let .marked(bonus, _) = active.effect else { return }

        state.remaining += bonus
        state.dealt += bonus
        state.activeEffects.remove(at: index)
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .markedConsumed,
            actorName: state.combatant.name,
            abilityName: "Marked",
            target: state.combatant,
            amount: bonus,
            keyword: .physical
        ))
    }
}
