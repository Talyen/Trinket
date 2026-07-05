import Foundation
import TrinketCore
import TrinketContent

/// Adds bonus damage when the target is Marked. Consumption happens in
/// `MarkedConsumeStep` only after health is actually lost.
package struct MarkedBonusStep: DamageStep {
    public static let stepName = "MarkedBonus"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.sourceActorID != nil else { return }
        let effects = context.roster.activeEffects(for: state.combatant)
        guard effects.contains(where: { if case .marked = $0.effect { return true }; return false }) else {
            return
        }

        guard let index = effects.firstIndex(where: { if case .marked = $0.effect { return true }; return false }),
              case let .marked(bonus, _) = effects[index].effect
        else { return }

        state.remaining += bonus
        state.dealt += bonus
        state.markedBonusApplied = true
    }
}
