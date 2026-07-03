import Foundation
import TrinketCore
import TrinketContent

/// Applies Burn, Poison, and Bleed stacks through a mutation context.
public enum DoTApplicator {
    public static func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard context.health(of: effectTarget) > 0, potency > 0 else { return [] }
        let statBonus: Int
        if let actor = context.roster.combatant(for: sourceActorID) {
            statBonus = actor.primaryStats.statBonusForDamage(keyword: keyword)
        } else {
            statBonus = 0
        }
        let boostedPotency = potency + statBonus

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: context.logDoTDamage(
                context.applyDoTDamage(boostedPotency, keyword: keyword, to: effectTarget, sourceActorID: sourceActorID),
                keyword: keyword,
                target: effectTarget
            ))
        }

        var currentEffects = context.activeEffects(for: effectTarget)
        if let index = currentEffects.firstIndex(where: { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }) {
            let existingPotency = currentEffects[index].effect.potency ?? 0
            currentEffects[index].effect = effectCase(for: keyword, potency: existingPotency + boostedPotency)
            if currentEffects[index].sourceActorID == nil {
                currentEffects[index].sourceActorID = sourceActorID
            }
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: context.consumeNextEffectID(),
                    effect: effectCase(for: keyword, potency: boostedPotency),
                    remainingTicks: 0,
                    sourceActorID: sourceActorID
                )
            )
        }
        context.setActiveEffects(currentEffects, for: effectTarget)
        return collected
    }

    public static func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard context.health(of: effectTarget) > 0, potency > 0 else { return [] }

        let statBonus: Int
        if let actor = context.roster.combatant(for: sourceActorID) {
            statBonus = actor.primaryStats.statBonusForDamage(keyword: .bleed)
        } else {
            statBonus = 0
        }
        let boostedPotency = potency + statBonus

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: context.logDoTDamage(
                context.applyDoTDamage(boostedPotency, keyword: .bleed, to: effectTarget, sourceActorID: sourceActorID),
                keyword: .bleed,
                target: effectTarget
            ))
        }

        context.appendEffect(
            .bleed(boostedPotency),
            to: effectTarget,
            sourceID: sourceActorID,
            remainingTicks: Effect.bleedDoTTickCount + context.modifiers(for: sourceActorID).bleedDurationBonus
        )
        return collected
    }

    private static func effectCase(for keyword: Keyword, potency: Int) -> Effect {
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        default: return .poison(potency)
        }
    }
}
