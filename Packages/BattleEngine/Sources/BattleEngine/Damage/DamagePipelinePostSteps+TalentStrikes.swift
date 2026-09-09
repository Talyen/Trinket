import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyBelowHealthStunBuildup(
        to state: inout DamageResolutionState,
        source: Combatant,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        target: Combatant,
        targetAlive: Bool,
        in context: inout BattleState,
    ) {
        guard triggers.attackStunBuildupBelowHealthBonus > 0, targetAlive,
              triggers.attackStunBuildupBelowHealthThreshold > 0,
              context.roster.maxHealth(for: source) > 0,
              Double(context.roster.health(for: source)) / Double(context.roster.maxHealth(for: source))
              < triggers.attackStunBuildupBelowHealthThreshold
        else { return }
        state.damageEvents.append(contentsOf: appendMeterCharge(
            triggers.attackStunBuildupBelowHealthBonus,
            keyword: .stun,
            to: target,
            sourceActorID: sourceActorID,
            in: &context,
        ))
    }

    static func applyPhysicalStunAfflictions(
        to state: inout DamageResolutionState,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        target: Combatant,
        targetAlive: Bool,
        in context: inout BattleState,
    ) {
        if triggers.physicalAttackFlatStunBuildup > 0, keyword == .physical, targetAlive {
            state.damageEvents.append(contentsOf: appendMeterCharge(
                triggers.physicalAttackFlatStunBuildup,
                keyword: .stun,
                to: target,
                sourceActorID: sourceActorID,
                in: &context,
            ))
        }
        if triggers.physicalVsStunnedStunBuildup > 0, keyword == .physical, targetAlive,
           context.roster.hasControlStatus(for: target, keyword: .stun) {
            state.damageEvents.append(contentsOf: appendMeterCharge(
                triggers.physicalVsStunnedStunBuildup,
                keyword: .stun,
                to: target,
                sourceActorID: sourceActorID,
                in: &context,
            ))
        }
        applyPulverizeStrike(
            to: &state,
            sourceActorID: sourceActorID,
            triggers: triggers,
            keyword: keyword,
            target: target,
            targetAlive: targetAlive,
            in: &context,
        )
    }

    static func applyBleedingPreyHeal(
        triggers: CombatTraitTriggers,
        source: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        context.healEmitting(
            amount: triggers.onAttackBleedingEnemyHeal,
            target: source,
            source: source,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                "onAttackBleedingEnemyHeal",
                for: source,
                fallback: "Bloodprice",
                in: context,
            ),
        )
    }

    private static func applyPulverizeStrike(
        to state: inout DamageResolutionState,
        sourceActorID: String,
        triggers: CombatTraitTriggers,
        keyword: Keyword,
        target: Combatant,
        targetAlive: Bool,
        in context: inout BattleState,
    ) {
        guard triggers.firstPhysicalBleedStunPerTurn, keyword == .physical, targetAlive,
              context.claimTurnGuard(.pulverize, actorID: sourceActorID)
        else { return }
        state.damageEvents.append(contentsOf: appendBleed(
            potency: 1,
            to: target,
            sourceActorID: sourceActorID,
            in: &context,
        ))
        state.damageEvents.append(contentsOf: appendMeterCharge(
            1,
            keyword: .stun,
            to: target,
            sourceActorID: sourceActorID,
            in: &context,
        ))
    }
}
