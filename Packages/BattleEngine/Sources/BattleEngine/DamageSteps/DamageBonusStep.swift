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
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context
                )
                : 0
            if let runtime = context.roster.runtime(for: actor.combatant),
               !runtime.hasTriggeredAmbush {
                let ambushBonus = context.modifiers(for: sourceActorID).ambushBonusDamage
                if ambushBonus > 0 {
                    state.itemBonus += ambushBonus
                    context.roster.mutateRuntime(for: actor.combatant) { $0.hasTriggeredAmbush = true }
                }
            }
        }
        state.remaining = state.amount + state.statBonus + state.itemBonus
        state.dealt = state.remaining
    }

    private func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleEngineContext
    ) -> Int {
        var bonus = context.modifiers(for: sourceActorID).damageDealtBonus(for: keyword)
        if sourceActorID == context.build.petID {
            bonus += context.build.heroModifiers.petDamageDealtBonus
        }
        return bonus
    }
}
