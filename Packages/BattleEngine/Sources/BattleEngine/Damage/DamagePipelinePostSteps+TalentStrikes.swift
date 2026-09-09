import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyAdditionalHolyDamage(
        _ amount: Int,
        to state: inout DamageResolutionState,
        source: Combatant,
        in context: inout BattleState,
    ) {
        guard amount > 0, context.roster.health(for: source) > 0,
              context.roster.health(for: state.combatant) > 0 else { return }
        state.damageEvents.append(contentsOf: resolveRetaliation(
            amount: amount, keyword: .holy, target: state.combatant,
            sourceActorID: source.id, in: &context,
        ).events)
    }

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
        state.damageEvents.append(contentsOf: resolveRetaliation(
            amount: triggers.attackStunBuildupBelowHealthBonus,
            keyword: .stun,
            target: target,
            sourceActorID: sourceActorID,

            in: &context,
        ).events)
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
            state.damageEvents.append(contentsOf: resolveRetaliation(
                amount: triggers.physicalAttackFlatStunBuildup,
                keyword: .stun,
                target: target,
                sourceActorID: sourceActorID,

                in: &context,
            ).events)
        }
        if triggers.physicalVsStunnedStunBuildup > 0, keyword == .physical, targetAlive,
           context.roster.hasControlStatus(for: target, keyword: .stun) {
            state.damageEvents.append(contentsOf: resolveRetaliation(
                amount: triggers.physicalVsStunnedStunBuildup,
                keyword: .stun,
                target: target,
                sourceActorID: sourceActorID,

                in: &context,
            ).events)
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
        state.damageEvents.append(contentsOf: DoTApplicator.applyBleed(
            potency: 1,
            to: target,
            sourceActorID: sourceActorID,
            application: .reaction,
            in: &context,
        ))
        state.damageEvents.append(contentsOf: resolveRetaliation(
            amount: 1,
            keyword: .stun,
            target: target,
            sourceActorID: sourceActorID,

            in: &context,
        ).events)
    }
}
