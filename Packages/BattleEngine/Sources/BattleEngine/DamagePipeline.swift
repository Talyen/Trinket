import Foundation
import TrinketCore
import TrinketContent

/// Execution phase for a damage pipeline step. Future RNG mechanics (crit,
/// block) register in `.stochastic`; leech and CC buildup stay in `.post`.
package enum DamagePhase: Sendable {
    /// Rolls battle RNG and may short-circuit the pipeline (dodge today).
    case stochastic
    /// Deterministic damage math and HP subtraction.
    case resolution
    /// Side effects after final damage is known (leech, control-meter buildup).
    case post
}

/// Ordered registry and runner for damage resolution steps.
package enum DamagePipeline {
    private struct Step {
        let name: String
        let phase: DamagePhase
        let apply: (inout DamageResolutionState, inout BattleEngineContext) -> Void
    }

    private static let steps: [Step] = [
        Step(name: DodgeGateStep.stepName, phase: DodgeGateStep.phase) { state, context in
            var step = DodgeGateStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: CriticalGateStep.stepName, phase: CriticalGateStep.phase) { state, context in
            var step = CriticalGateStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: DamageBonusStep.stepName, phase: DamageBonusStep.phase) { state, context in
            var step = DamageBonusStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: MarkedBonusStep.stepName, phase: MarkedBonusStep.phase) { state, context in
            var step = MarkedBonusStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: MitigationStep.stepName, phase: MitigationStep.phase) { state, context in
            var step = MitigationStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: ItemReductionStep.stepName, phase: ItemReductionStep.phase) { state, context in
            var step = ItemReductionStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: ShieldAbsorptionStep.stepName, phase: ShieldAbsorptionStep.phase) { state, context in
            var step = ShieldAbsorptionStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: CriticalMultiplyStep.stepName, phase: CriticalMultiplyStep.phase) { state, context in
            var step = CriticalMultiplyStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: TakeDamageStep.stepName, phase: TakeDamageStep.phase) { state, context in
            var step = TakeDamageStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: MarkedConsumeStep.stepName, phase: MarkedConsumeStep.phase) { state, context in
            var step = MarkedConsumeStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: DeathsDoorStep.stepName, phase: DeathsDoorStep.phase) { state, context in
            var step = DeathsDoorStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: LeechStep.stepName, phase: LeechStep.phase) { state, context in
            var step = LeechStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: ControlMeterStep.stepName, phase: ControlMeterStep.phase) { state, context in
            var step = ControlMeterStep()
            step.apply(to: &state, in: &context)
        },
        Step(name: ReactiveOnHitStep.stepName, phase: ReactiveOnHitStep.phase) { state, context in
            var step = ReactiveOnHitStep()
            step.apply(to: &state, in: &context)
        }
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
            if state.isRetaliation, step.name == ReactiveOnHitStep.stepName {
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
            qualifiesForAmbush: request.options.qualifiesForAmbush
        )

        var executed: [String] = []
        run(state: &state, in: &context) { executed.append($0) }
        return executed
    }
}
