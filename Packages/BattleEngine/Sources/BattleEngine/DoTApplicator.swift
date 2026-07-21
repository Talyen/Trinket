import Foundation
import TrinketContent
import TrinketCore

/// Applies Burn, Poison, and Bleed stacks through a mutation context.
package enum DoTApplicator {
    public static func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool,
        suppressAffixReactions: Bool = false,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: potency,
                keyword: keyword,
                target: effectTarget,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        var currentEffects = context.roster.activeEffects(for: effectTarget)
        if let index = currentEffects.firstIndex(where: { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }) {
            let existingPotency = currentEffects[index].effect.potency ?? 0
            currentEffects[index].effect = effectCase(for: keyword, potency: existingPotency + potency)
            currentEffects[index].sourceActorID = sourceActorID
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: context.consumeNextEffectID(),
                    effect: effectCase(for: keyword, potency: potency),
                    remainingTurns: 0,
                    sourceActorID: sourceActorID
                )
            )
        }
        context.roster.setActiveEffects(currentEffects, for: effectTarget)
        if !suppressAffixReactions {
            collected.append(contentsOf: CombatReactionEngine.afterDecayingDoTApplied(
                keyword: keyword,
                to: effectTarget,
                sourceActorID: sourceActorID,
                in: &context
            ))
        }
        return collected
    }

    public static func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool,
        suppressAffixReactions: Bool = false,
        in context: inout BattleEngineContext
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: potency,
                keyword: .bleed,
                target: effectTarget,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        let didRefresh = CombatReactionEngine.refreshBleedOnReapplyIfNeeded(
            to: effectTarget,
            sourceActorID: sourceActorID,
            in: &context
        )
        if !didRefresh {
            context.appendEffect(
                .bleed(potency),
                to: effectTarget,
                sourceID: sourceActorID,
                remainingTurns: Effect.bleedDoTTurnCount + context.modifiers(for: sourceActorID).bleedDurationBonus
            )
        }
        if !suppressAffixReactions {
            collected.append(contentsOf: CombatReactionEngine.afterBleedApplied(
                to: effectTarget,
                sourceActorID: sourceActorID,
                in: &context
            ))
        }
        return collected
    }

    private static func effectCase(for keyword: Keyword, potency: Int) -> Effect {
        switch keyword {
        case .burn: .burn(potency)
        case .poison: .poison(potency)
        default: .poison(potency)
        }
    }
}
