import Foundation
import TrinketCore
import TrinketContent

/// Consumes Mark only when the attack dealt health damage.
package struct MarkedConsumeStep: DamageStep {
    public static let stepName = "MarkedConsume"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        guard state.markedBonusApplied, state.healthLost > 0 else { return }

        var effects = context.roster.activeEffects(for: state.combatant)
        guard let index = effects.firstIndex(where: { if case .marked = $0.effect { return true }; return false }),
              case let .marked(bonus, _) = effects[index].effect
        else { return }

        effects.remove(at: index)
        context.roster.setActiveEffects(effects, for: state.combatant)
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
