import Foundation
import TrinketCore
import TrinketContent

/// Step 2: computes `statBonus` (per-stat contribution) and `itemBonus`
/// (item-modifier contribution) and adds both to `remaining`.
package struct DamageBonusStep: DamageStep {
    public static let stepName = "DamageBonus"
    public static let phase: DamagePhase = .resolution

    public init() {}

    public func apply(to state: inout DamageResolutionState, in context: inout BattleEngineContext) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.applyStatBonus
                ? actor.primaryStats.statBonusForDamage(keyword: damageKeyword)
                : 0
            state.itemBonus = state.applyItemBonus
                ? context.modifiers(for: sourceActorID).damageDealtBonus(for: damageKeyword)
                : 0
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
        state.dealt = state.remaining
    }
}
