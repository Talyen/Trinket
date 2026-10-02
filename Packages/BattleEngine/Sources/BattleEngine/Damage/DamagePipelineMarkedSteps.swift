import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyMarkedBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit, state.sourceActorID != nil else { return }
        for active in context.roster.activeEffects(for: state.combatant) {
            if case let .marked(bonus, _) = active.effect {
                state.remaining += bonus
                state.dealt += bonus
                state.markedBonusApplied = true
                break
            }
        }
    }

    static func applyMarkedConsume(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.markedBonusApplied else { return }

        var markedBonus: Int?
        for active in context.roster.activeEffects(for: state.combatant) {
            if case let .marked(bonus, _) = active.effect {
                markedBonus = bonus
                break
            }
        }
        guard let bonus = markedBonus else { return }

        ActiveEffectMutation.removeMatching(from: state.combatant, in: &context) {
            if case .marked = $0 {
                return true
            }
            return false
        }
        state.damageEvents.append(context.nextEvent(
            kind: .effect,
            effectKind: .markedConsumed,
            actorName: state.combatant.name,
            abilityName: "Marked",
            target: state.combatant,
            amount: bonus,
            keyword: .physical,
        ))
    }
}
