import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyHolyStunReactions(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        in context: inout BattleState
    ) {
        guard state.buildupDamage > 0, triggers.holyStunBuildupPercent > 0 else { return }
        let buildup = CombatRounding.scaled(
            state.buildupDamage,
            multiplier: triggers.holyStunBuildupPercent
        )
        let stunEvents = ControlMeterEngine.applyMeterCharge(
            buildup,
            keyword: .stun,
            to: state.combatant,
            sourceActorID: sourceActorID,
            applyFightPacing: false,
            in: &context
        )
        state.damageEvents.append(contentsOf: stunEvents)
        guard triggers.holyTriggeredStunGoldFlat > 0,
              stunEvents.contains(where: {
                  $0.effectKind == .controlTriggered && $0.keyword == .stun
              })
        else { return }
        state.damageEvents.append(contentsOf: context.grantGoldEvent(
            triggers.holyTriggeredStunGoldFlat,
            to: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                "holyTriggeredStunGoldFlat",
                for: source,
                fallback: "Golden Verdict",
                in: context
            )
        ))
    }
}
