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

        applyDodgeGate(to: &state, in: &context)
        if state.isDodged {
            return
        }
        state.targetStatus = DamageTargetStatus(for: state.combatant, in: context)
        applyCriticalGate(to: &state, in: &context)
        applyCriticalBlockSteal(to: &state, in: &context)
        applyDamageBonus(to: &state, in: &context)
        applyFightPacing(to: &state, in: &context)

        applyMarkedBonus(to: &state, in: &context)
        applyItemReduction(to: &state, in: &context)
        applyCriticalMultiply(to: &state, in: &context)
        if state.options.isOriginalCardDamage, state.amount > 0, state.combatant.role == .enemy {
            let bonus = CombatTriggerEngine.heroCardDamageBonus(keyword: state.damageKeyword, sourceID: state.sourceActorID, in: &context)
            state.remaining += bonus
            state.buildupDamage += bonus
            state.heroCardBlockIgnore = CombatTriggerEngine.heroCardBlockIgnore(
                keyword: state.damageKeyword,
                sourceID: state.sourceActorID,
                in: &context,
            )
        }
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
    }
}
