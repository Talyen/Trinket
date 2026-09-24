import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyVenomtrail(to state: inout DamageResolutionState, in context: BattleState) {
        guard state.amount > 0, state.damageKeyword == .poison, state.targetStatus.isBleeding,
              state.combatant.role == .enemy, let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.role != .enemy
        else { return }
        let bonus = context.modifiers(for: sourceActorID).triggers.poisonDamageVsBleedingFlat
        state.remaining += bonus
        state.itemBonus += bonus
    }

    static func applyHallowbreak(to state: inout DamageResolutionState, in context: BattleState) {
        guard state.damageKeyword == .holy, state.targetStatus.isStunned,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID), source.role != .enemy
        else { return }
        let bonus = context.modifiers(for: sourceActorID).triggers.holyDamageVsStunnedPercent
        if bonus > 0 {
            state.remaining = CombatRounding.scaled(state.remaining, multiplier: 1 + bonus)
        }
    }
}
