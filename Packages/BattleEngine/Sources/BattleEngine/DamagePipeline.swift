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
        let apply: @Sendable (inout DamageResolutionState, inout BattleEngineContext) -> Void
    }

    /// Canonical damage resolution order. Flat Armor runs after item mods and
    /// crit so it mitigates the final pre-Block hit amount; Block absorbs last.
    package static let steps: [Step] = [
        Step(name: "DodgeGate", phase: .stochastic, apply: applyDodgeGate),
        Step(name: "CriticalGate", phase: .stochastic, apply: applyCriticalGate),
        Step(name: "DamageBonus", phase: .resolution, apply: applyDamageBonus),
        Step(name: "Hexmark", phase: .resolution, apply: applyHexmark),
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
        Step(name: "ReactiveOnHit", phase: .post, apply: applyReactiveOnHit)
    ]

    public static var canonicalNames: [String] {
        steps.map(\.name)
    }

    public static func run(
        state: inout DamageResolutionState,
        in context: inout BattleEngineContext,
        onStep: ((String) -> Void)? = nil
    ) {
        for step in steps {
            if state.isRetaliation, step.name == "ReactiveOnHit" {
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
        in context: inout BattleEngineContext
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
            isRetaliation: request.options.isRetaliation,
            qualifiesForAmbush: request.options.qualifiesForAmbush,
            abilityHasLeech: request.options.abilityHasLeech
        )
        state.activeEffects = context.roster.activeEffects(for: request.target)

        var executed: [String] = []
        run(state: &state, in: &context) { executed.append($0) }
        return executed
    }
}
