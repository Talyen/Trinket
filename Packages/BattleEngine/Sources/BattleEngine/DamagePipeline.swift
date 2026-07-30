import Foundation
import TrinketContent
import TrinketCore

/// Execution phase for a damage pipeline step. Future RNG mechanics (crit,
/// block) register in `.stochastic`; leech and CC buildup stay in `.post`.
package enum DamagePhase {
    /// Rolls battle RNG and may short-circuit the pipeline (dodge today).
    case stochastic
    /// Deterministic damage math and HP subtraction.
    case resolution
    /// Side effects after final damage is known (leech, control-meter buildup).
    case post
}

/// Ordered registry and runner for damage resolution steps.
package enum DamagePipeline {
    package struct Step {
        package let name: String
        package let phase: DamagePhase
        let apply: @Sendable (inout DamageResolutionState, inout BattleState) -> Void
    }

    /// Canonical damage resolution order. Toughness-based inherent DR runs after
    /// item mods and crit so it mitigates the final pre-Block hit amount; Block absorbs last.
    package static let steps: [Step] = [
        Step(name: "DodgeGate", phase: .stochastic, apply: applyDodgeGate),
        Step(name: "CriticalGate", phase: .stochastic, apply: applyCriticalGate),
        Step(name: "DamageBonus", phase: .resolution, apply: applyDamageBonus),
        Step(name: "FightPacing", phase: .resolution, apply: applyFightPacing),
        Step(name: "MarkedBonus", phase: .resolution, apply: applyMarkedBonus),
        Step(name: "ItemReduction", phase: .resolution, apply: applyItemReduction),
        Step(name: "CriticalMultiply", phase: .resolution, apply: applyCriticalMultiply),
        Step(name: "Mitigation", phase: .resolution, apply: applyMitigation),
        Step(name: "ShieldAbsorption", phase: .resolution, apply: applyShieldAbsorption),
        Step(name: "TakeDamage", phase: .resolution, apply: applyTakeDamage),
        Step(name: "MarkedConsume", phase: .resolution, apply: applyMarkedConsume),
        Step(name: "DeathsDoor", phase: .resolution, apply: applyDeathsDoor),
        Step(name: "Leech", phase: .post, apply: applyLeech),
        Step(name: "ControlMeter", phase: .post, apply: applyControlMeter),
        Step(name: "ReactiveOnHit", phase: .post, apply: applyReactiveOnHit),
        Step(name: "HolyReaction", phase: .post, apply: applyHolyReaction),
        Step(name: "StunReaction", phase: .post, apply: applyStunReaction),
        Step(name: "BurnReaction", phase: .post, apply: applyBurnReaction),
        Step(name: "CriticalReaction", phase: .post, apply: applyCriticalReaction),
    ]

    public static var canonicalNames: [String] {
        steps.map(\.name)
    }

    public static func run(
        state: inout DamageResolutionState,
        in context: inout BattleState,
        onStep: ((String) -> Void)? = nil
    ) {
        // Authored "Lose N Health" costs are exact HP — not attacks.
        if state.isHealthCost {
            state.remaining = state.amount
            state.dealt = state.amount
            onStep?("TakeDamage")
            applyTakeDamage(to: &state, in: &context)
            onStep?("DeathsDoor")
            applyDeathsDoor(to: &state, in: &context)
            return
        }

        for step in steps {
            // Retaliation / DoT-style hits must not nest further reaction pipelines
            // (Whiplash stun → ControlMeter → afterEnemyStunned → Knockout → …).
            if state.isRetaliation,
               step.name == "ReactiveOnHit"
               || step.name == "HolyReaction"
               || step.name == "StunReaction"
               || step.name == "BurnReaction"
               || step.name == "CriticalReaction"
               || step.name == "ControlMeter" {
                continue
            }
            onStep?(step.name)
            step.apply(&state, &context)
            if step.phase == .stochastic, state.isDodged {
                return
            }
        }
    }

    /// Test helper: records step names actually executed for a damage request.
    package static func executedStepNames(
        for request: DamageRequest,
        in context: inout BattleState
    ) -> [String] {
        guard request.amount > 0 else { return [] }

        var state = DamageResolutionState(
            amount: request.amount,
            combatant: request.target,
            sourceActorID: request.sourceActorID,
            damageKeyword: request.keyword,
            applyStatBonus: request.options.applyStatBonus,
            applyItemBonus: request.options.applyItemBonus,
            applyDodge: request.options.applyDodge,
            abilityCriticalChanceBonus: request.options.abilityCriticalChanceBonus,
            guaranteedCriticalIfEnemyBuffed: request.options.guaranteedCriticalIfEnemyBuffed,
            guaranteedCritical: request.options.guaranteedCritical,
            isRetaliation: request.options.isRetaliation,
            qualifiesForAmbush: request.options.qualifiesForAmbush,
            isAttackHit: request.options.isAttackHit,
            abilityHasLeech: request.options.abilityHasLeech,
            isHealthCost: request.options.isHealthCost
        )
        state.activeEffects = context.roster.activeEffects(for: request.target)

        var executed: [String] = []
        run(state: &state, in: &context) { executed.append($0) }
        return executed
    }
}
