import Foundation
import TrinketCore
import TrinketContent

/// Damage resolution orchestration. Healing, control meters, and DoT entry points
/// live on `HealingEngine`, `ControlMeterEngine`, and `DoTDamage`.
package enum CombatPipeline {
    package static func resolveDamage(
        _ request: DamageRequest,
        in context: inout BattleEngineContext
    ) -> CombatOutcome {
        guard request.amount > 0 else { return .empty }

        var state = DamageResolutionState(
            amount: request.amount,
            combatant: request.target,
            sourceActorID: request.sourceActorID,
            damageKeyword: request.keyword,
            applyStatBonus: request.options.applyStatBonus,
            applyItemBonus: request.options.applyItemBonus,
            applyDodge: request.options.applyDodge
        )

        DamagePipeline.run(state: &state, in: &context)

        return CombatOutcome.fromDamage(state: state)
    }
}
