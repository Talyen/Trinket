import TrinketContent
import TrinketCore

extension UniqueCombatEngine {
    static func retainStun(
        _ buildup: Int,
        on target: Combatant,
        sourceActorID: String?,
        in context: inout BattleState,
    ) {
        guard target.role == .enemy, let sourceActorID,
              let effect = context.roster.activeEffects(for: target).first(where: {
                  $0.keyword == .stun && $0.effect.isActionSkipPending
              })
        else { return }
        let percent = context.modifiers(for: sourceActorID).triggers.stunRetainedBuildupPercent
        let retained = CombatRounding.scaled(buildup, multiplier: percent)
        if retained > 0 {
            context.uniques.retainedStunByEffectID[effect.id] = retained
        }
    }

    static func recoveredStun(_ active: ActiveEffect, in context: inout BattleState) -> ActiveEffect? {
        guard let retained = context.uniques.retainedStunByEffectID.removeValue(forKey: active.id),
              let values = active.effect.controlMeterValues
        else { return nil }
        var updated = active
        updated.effect = .controlMeter(.stun, retained, values.threshold)
        updated.remainingTurns = 0
        return updated
    }

    static func recoverStunBeforeClearing(on actor: Combatant, in context: inout BattleState) {
        var effects = context.roster.activeEffects(for: actor)
        for index in effects.indices {
            let active = effects[index]
            if active.effect.isActionSkipPending, !active.isAwaitingActionSkip,
               let restored = recoveredStun(active, in: &context) {
                effects[index] = restored
            }
        }
        context.roster.setActiveEffects(effects, for: actor)
    }
}
