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
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        // Golden Touch: the next card's status effects are doubled.
        var resolvedPotency = potency
        if let source = context.roster.combatant(for: sourceActorID),
           let runtime = context.roster.runtime(for: source.combatant),
           runtime.pendingDoubleStatusNextCard {
            resolvedPotency *= 2
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDoubleStatusNextCard = false }
        }

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: resolvedPotency,
                keyword: keyword,
                target: effectTarget,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        var currentEffects = context.roster.activeEffects(for: effectTarget)
        if let index = currentEffects.firstIndex(where: { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }) {
            let existingPotency = currentEffects[index].effect.potency ?? 0
            currentEffects[index].effect = effectCase(for: keyword, potency: existingPotency + resolvedPotency)
            currentEffects[index].sourceActorID = sourceActorID
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: context.consumeNextEffectID(),
                    effect: effectCase(for: keyword, potency: resolvedPotency),
                    remainingTurns: 0,
                    sourceActorID: sourceActorID
                )
            )
        }
        context.roster.setActiveEffects(currentEffects, for: effectTarget)
        if !suppressAffixReactions {
            collected.append(contentsOf: CombatTriggerEngine.afterDecayingDoTApplied(
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
        durationTurns: Int? = nil,
        in context: inout BattleState
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        // Golden Touch: the next card's status effects are doubled.
        var resolvedPotency = potency
        if let source = context.roster.combatant(for: sourceActorID),
           let runtime = context.roster.runtime(for: source.combatant),
           runtime.pendingDoubleStatusNextCard {
            resolvedPotency *= 2
            context.roster.mutateRuntime(for: source.combatant) { $0.pendingDoubleStatusNextCard = false }
        }

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: resolvedPotency,
                keyword: .bleed,
                target: effectTarget,
                sourceActorID: sourceActorID,
                in: &context
            ).events)
        }

        // Serrated Blades / Open Wounds: applying Bleed to a Bleeding target reacts.
        let alreadyBleeding = context.roster.activeEffects(for: effectTarget).contains(where: \.effect.isBleed)
        if alreadyBleeding {
            let sourceTriggers = context.modifiers(for: sourceActorID).triggers
            if sourceTriggers.onBleedAppliedToBleedingExtendTurns > 0 {
                var effects = context.roster.activeEffects(for: effectTarget)
                for index in effects.indices where effects[index].effect.isBleed {
                    effects[index].remainingTurns = min(
                        5,
                        effects[index].remainingTurns + sourceTriggers.onBleedAppliedToBleedingExtendTurns
                    )
                }
                context.roster.setActiveEffects(effects, for: effectTarget)
            }
            if sourceTriggers.onBleedAppliedToBleedingDealDamage > 0 {
                collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                    basePotency: sourceTriggers.onBleedAppliedToBleedingDealDamage,
                    keyword: .bleed,
                    target: effectTarget,
                    sourceActorID: sourceActorID,
                    in: &context
                ).events)
            }
        }

        context.appendEffect(
            .bleed(resolvedPotency),
            to: effectTarget,
            sourceID: sourceActorID,
            remainingTurns: durationTurns ?? (Effect.bleedDoTTurnCount + context.modifiers(for: sourceActorID).bleedDurationBonus)
        )
        if !suppressAffixReactions {
            collected.append(contentsOf: CombatTriggerEngine.afterBleedApplied(
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
