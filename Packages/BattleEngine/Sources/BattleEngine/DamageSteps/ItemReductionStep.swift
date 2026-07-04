import Foundation
import TrinketCore
import TrinketContent

/// Step 4: applies the target's `damageTakenReduction` for the damage
/// keyword, if any. Records `buildupDamage` for stun/freeze buildup after
/// mitigation and item reduction, but before shields absorb damage.
package struct ItemReductionStep: DamageStep {
    public static let stepName = "ItemReduction"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        _ = context
        guard state.remaining > 0 else {
            state.buildupDamage = 0
            return
        }
        guard let damageKeyword = state.damageKeyword else {
            state.buildupDamage = state.remaining
            return
        }
        let reduction = context.modifiers(for: state.combatant.id).damageTakenReduction(for: damageKeyword)
        if reduction > 0 {
            state.remaining = Int(ceil(Double(state.remaining) * (1 - reduction)))
        }
        state.buildupDamage = state.remaining
    }
}
