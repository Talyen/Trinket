import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyLeech(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard !state.options.suppressLeech,
              let sourceActorID = state.sourceActorID,
              state.healthLost > 0 || (state.blockedAmount > 0 && context.modifiers(for: sourceActorID).triggers.leechOnBlockDamage),
              sourceActorID != state.combatant.id
        else { return }
        let leechOutcome = HealingEngine.leechFromDamage(
            state.healthLost,
            sourceActorID: sourceActorID,
            target: state.combatant,
            blockedAmount: state.blockedAmount,
            abilityHasLeech: state.options.abilityHasLeech || state.talentAttackHasLeech,
            criticalAttack: state.isCritical && state.options.isAttackHit,
            attackHit: state.options.isAttackHit,
            damageKeyword: state.damageKeyword,
            in: &context,
        )
        state.damageEvents.append(contentsOf: leechOutcome.events)
        state.didLeech = leechOutcome.flags.contains(.leeched)
        applyFinalCompanionLeechRewards(to: &state, in: &context)
    }

    static func applyKeywordReactions(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.healthLost > 0,
              let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID)
        else { return }

        switch keyword {
        case .holy:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHolyDamageDealt(
                to: state.combatant,
                source: source.combatant,
                attackHit: state.options.isAttackHit && !state.options.isRetaliation,
                sourceHadNoBlock: state.sourceHadNoBlockAtHit,
                in: &context,
            ))
        case .stun:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterStunDamageDealt(
                to: state.combatant,
                source: source.combatant,
                in: &context,
            ))
        case .burn:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBurnDamageDealt(
                to: state.combatant,
                source: source.combatant,
                healthLost: state.healthLost,
                in: &context,
            ))
        case .freeze:
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterFreezeDamageDealt(
                to: state.combatant,
                source: source.combatant,
                amount: state.healthLost,
                in: &context,
            ))
        default:
            break
        }

        guard state.combatant.role == .enemy, source.combatant.role != .enemy,
              keyword == .burn || keyword == .freeze || keyword == .holy else { return }
        for owner in [BattleParticipant.hero, .companion] {
            let wearer = context.roster[owner]
            guard wearer.isAlive, wearer.currentMana < wearer.maxMana else { continue }
            let chance = context.modifiers(for: wearer.combatant.id).triggers.threefoldElementalDamageManaChancePercent
            guard chance > 0, BattleChance.succeeds(probability: chance, using: &context.rng) else { continue }
            state.damageEvents.append(contentsOf: context.restoreManaEmitting(
                1,
                to: wearer.combatant,
                abilityName: "Threefold Grace",
            ))
        }
    }

    static func applyCriticalReaction(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.isCritical,
              state.healthLost > 0,
              let source = state.partySource(in: context),
              state.combatant.role == .enemy
        else { return }
        state.damageEvents.append(contentsOf: CombatTriggerEngine.afterCriticalHit(
            to: state.combatant,
            source: source.combatant,
            in: &context,
        ))
    }

    static func applyControlMeter(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0,
              let damageKeyword = state.damageKeyword,
              damageKeyword == .stun || damageKeyword == .freeze,
              context.roster.health(for: state.combatant) > 0
        else { return }
        let wasControlled = context.roster.hasControlStatus(for: state.combatant, keyword: damageKeyword)
        let criticalMultiplier: Double = if damageKeyword == .freeze, state.isCritical, state.options.isAttackHit,
                                            let sourceActorID = state.sourceActorID {
            context.modifiers(for: sourceActorID).triggers.freezeCriticalBuildupMultiplier
        } else {
            1
        }
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            CombatRounding.scaled(state.remaining, multiplier: criticalMultiplier),
            keyword: damageKeyword,
            to: state.combatant,
            sourceActorID: state.sourceActorID,
            applyFightPacing: false,
            in: &context,
        ))
        state.didTriggerControl = !wasControlled && context.roster.hasControlStatus(for: state.combatant, keyword: damageKeyword)
    }
}
