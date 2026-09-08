import Foundation
import TrinketContent
import TrinketCore

package enum DamagePipeline {
    package static func run(
        state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.options.isHealthCost {
            state.remaining = state.amount
            state.dealt = state.amount
            applyTakeDamage(to: &state, in: &context)
            applyDeathsDoor(to: &state, in: &context)
            return
        }

        if state.damageKeyword == .burn,
           context.modifiers(for: state.combatant.id).triggers.undyingEmber,
           context.roster.isDeathsDoorActive(for: state.combatant) {
            applyOutgoingDamage(to: &state, in: &context)
            applyMitigation(to: &state, in: &context)
            var request = HealRequest(
                amount: state.remaining, target: state.combatant, sourceActorID: state.combatant.id,
                logAs: .instantHeal(actorName: state.combatant.name, abilityName: "Undying Ember", keyword: .health),
            )
            request.usesResolvedHealing = true
            state.damageEvents.append(contentsOf: HealingEngine.resolveHeal(request, in: &context).events)
            state.remaining = 0
            state.buildupDamage = 0
            state.dealt = 0
            return
        }

        applyDodgeGate(to: &state, in: &context)
        if state.isDodged {
            return
        }
        state.targetStatus = DamageTargetStatus(for: state.combatant, in: context)
        applyOutgoingDamage(to: &state, in: &context)
        applyPreparedAttackReduction(to: &state, in: &context)
        applyMitigation(to: &state, in: &context)
        applyShieldAbsorption(to: &state, in: &context)
        applyTakeDamage(to: &state, in: &context)
        applyMarkedConsume(to: &state, in: &context)
        applyDeathsDoor(to: &state, in: &context)

        if state.options.isOriginalCardDamage, state.amount > 0, state.combatant.role == .enemy {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterHeroCardHit(
                keyword: state.damageKeyword, sourceID: state.sourceActorID, critical: state.isCritical,
                fullyBlocked: state.blockedAmount > 0 && state.remaining == 0,
                blockBroken: state.heroCardBlockBroken, targetWasFrozen: state.targetStatus.isFrozen, in: &context,
            ))
        }

        if state.damageKeyword == .bleed {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.afterBleedDamage(
                healthLost: state.healthLost, target: state.combatant,
                sourceActorID: state.sourceActorID, in: &context,
            ))
        }
        applyLeech(to: &state, in: &context)
        applyTalentDamageApplications(to: &state, in: &context)
        applyTalentMirroredReactions(to: &state, in: &context)

        if !state.options.isRetaliation {
            applyControlMeter(to: &state, in: &context)
            applyReactiveOnHit(to: &state, in: &context)
            applyKeywordReactions(to: &state, in: &context)
            applyCriticalReaction(to: &state, in: &context)
        } else if state.options.applyControlMeter {
            applyControlMeter(to: &state, in: &context)
        }
        state.damageEvents.append(contentsOf: UniqueCombatEngine.afterDamage(state, in: &context))
    }

    static func applyWinterWake(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard !state.options.causedByDodge, state.options.isAttackHit,
              context.modifiers(for: state.combatant.id).triggers.wintersWake,
              let attackerID = state.sourceActorID,
              let attacker = context.roster.combatant(for: attackerID), attacker.isAlive else { return }
        var preview = context
        var avoided = state
        avoided.targetStatus = DamageTargetStatus(for: state.combatant, in: preview)
        applyOutgoingDamage(to: &avoided, in: &preview)
        applyMitigation(to: &avoided, in: &preview)
        let amount = CombatRounding.scaled(avoided.remaining, multiplier: 0.5)
        guard amount > 0 else { return }
        var options = DamageOptions.dodgeTriggeredControlReaction
        options.usesResolvedOutgoingDamage = true
        let outcome = context.resolveDamage(DamageRequest(
            amount: amount, target: attacker.combatant, keyword: .freeze,
            sourceActorID: state.combatant.id, options: options,
        ))
        state.damageEvents.append(contentsOf: outcome.events)
        if outcome.healthLost > 0 {
            state.damageEvents.append(context.nextEvent(
                kind: .abilityDamage, actorName: state.combatant.name, abilityName: "Winter’s Wake",
                target: attacker.combatant, amount: outcome.healthLost, keyword: .freeze,
            ))
        }
    }

    private static func applyOutgoingDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if state.options.usesResolvedOutgoingDamage {
            state.remaining = state.amount
            state.dealt = state.amount
            state.isCritical = state.options.guaranteedCritical
        } else {
            UniqueCombatEngine.captureEnemyBlock(for: &state, in: context)
            applyCriticalGate(to: &state, in: &context)
            applyCriticalBlockSteal(to: &state, in: &context)
            applyDamageBonus(to: &state, in: &context)
            applyFightPacing(to: &state, in: &context)
            applyMarkedBonus(to: &state, in: &context)
            UniqueCombatEngine.applyStoredDamage(to: &state, in: &context)
            state.uniqueOutgoingDamage = CombatRounding.scaled(
                state.remaining,
                multiplier: state.isCritical ? criticalMultiplier(for: state.sourceActorID, in: context) : 1,
            )
        }
        applyItemReduction(to: &state, in: &context)
        if !state.options.usesResolvedOutgoingDamage {
            applyCriticalMultiply(to: &state, in: &context)
        }
        if state.options.isOriginalCardDamage, state.amount > 0, state.combatant.role == .enemy {
            let bonus = CombatTriggerEngine.heroCardDamageBonus(keyword: state.damageKeyword, sourceID: state.sourceActorID, in: &context)
            state.remaining += bonus
            state.buildupDamage += bonus
            state.uniqueOutgoingDamage += bonus
            state.heroCardBlockIgnore = CombatTriggerEngine.heroCardBlockIgnore(
                keyword: state.damageKeyword,
                sourceID: state.sourceActorID,
                in: &context,
            )
        }
    }
}
