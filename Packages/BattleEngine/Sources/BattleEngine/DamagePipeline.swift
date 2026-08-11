import Foundation
import TrinketContent
import TrinketCore

/// Runner for a single, ordered damage resolution sequence.
package enum DamagePipeline {
    /// Canonical damage resolution order. Toughness-based inherent DR runs after
    /// item mods and crit so it mitigates the final pre-Block hit amount; Block
    /// absorbs last.
    package static func run(
        state: inout DamageResolutionState,
        in context: inout BattleState
    ) {
        // Authored "Lose N Health" costs are exact HP — not attacks.
        if state.isHealthCost {
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
        applyCriticalGate(to: &state, in: &context)
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

        // Retaliation / DoT-style hits must not nest further reaction pipelines
        // (Whiplash stun → ControlMeter → afterEnemyStunned → Knockout → …).
        if !state.isRetaliation {
            applyControlMeter(to: &state, in: &context)
            applyReactiveOnHit(to: &state, in: &context)
            applyKeywordReactions(to: &state, in: &context)
            applyCriticalReaction(to: &state, in: &context)
        }
    }
}
