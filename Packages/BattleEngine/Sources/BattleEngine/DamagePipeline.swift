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
        applyMitigation(to: &state, in: &context)
        applyShieldAbsorption(to: &state, in: &context)
        applyTakeDamage(to: &state, in: &context)
        applyMarkedConsume(to: &state, in: &context)
        applyDeathsDoor(to: &state, in: &context)

        applyLeech(to: &state, in: &context)
        applyTalentDamageApplications(to: &state, in: &context)

        if !state.options.isRetaliation {
            applyControlMeter(to: &state, in: &context)
            applyReactiveOnHit(to: &state, in: &context)
            applyKeywordReactions(to: &state, in: &context)
            applyCriticalReaction(to: &state, in: &context)
        } else if state.options.applyControlMeter {
            applyControlMeter(to: &state, in: &context)
        }
        state.damageEvents.append(contentsOf: BoonCombatEngine.afterDamage(state, in: &context))
    }
}
