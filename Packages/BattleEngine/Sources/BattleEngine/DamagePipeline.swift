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

/// Type-erased damage step for registry-driven pipeline execution.
package struct AnyDamageStep {
    package let name: String
    package let phase: DamagePhase
    private let body: (inout DamageResolutionState, inout BattleEngineContext) -> Void

    init<S: DamageStep>(_ stepType: S.Type) {
        name = S.stepName
        phase = S.phase
        body = { state, context in
            var step = stepType.init()
            step.apply(to: &state, in: &context)
        }
    }

    func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        body(&state, &context)
    }
}

/// Ordered registry and runner for damage resolution steps.
package enum DamagePipeline {
    package static var steps: [AnyDamageStep] {
        [
            AnyDamageStep(DodgeGateStep.self),
            AnyDamageStep(CriticalGateStep.self),
            AnyDamageStep(DamageBonusStep.self),
            AnyDamageStep(MarkedBonusStep.self),
            AnyDamageStep(MitigationStep.self),
            AnyDamageStep(ItemReductionStep.self),
            AnyDamageStep(ShieldAbsorptionStep.self),
            AnyDamageStep(CriticalMultiplyStep.self),
            AnyDamageStep(TakeDamageStep.self),
            AnyDamageStep(MarkedConsumeStep.self),
            AnyDamageStep(DeathsDoorStep.self),
            AnyDamageStep(LeechStep.self),
            AnyDamageStep(ControlMeterStep.self),
            AnyDamageStep(ReactiveOnHitStep.self)
        ]
    }

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
            step.apply(to: &state, in: &context)
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
