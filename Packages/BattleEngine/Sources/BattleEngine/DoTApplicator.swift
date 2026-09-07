import Foundation
import TrinketContent
import TrinketCore

package enum DoTApplicator {
    package static func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool,
        suppressAffixReactions: Bool = false,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        let resolvedPotency = goldenTouchPotency(potency, sourceActorID: sourceActorID, in: &context)

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: resolvedPotency,
                keyword: keyword,
                target: effectTarget,
                sourceActorID: sourceActorID,
                in: &context,
            ).events)
        }

        var currentEffects = context.roster.activeEffects(for: effectTarget)
        let appliedEffect = Effect.decayingDoT(keyword: keyword, potency: resolvedPotency)
        guard !context.interceptDebuff(appliedEffect, on: effectTarget) else { return collected }
        if let index = currentEffects.firstIndex(where: { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }) {
            let existingPotency = currentEffects[index].effect.potency ?? 0
            currentEffects[index].effect = Effect.decayingDoT(keyword: keyword, potency: existingPotency + resolvedPotency)
            currentEffects[index].sourceActorID = sourceActorID
        } else {
            currentEffects.append(
                ActiveEffect(
                    id: context.consumeNextEffectID(),
                    effect: appliedEffect,
                    remainingTurns: 0,
                    sourceActorID: sourceActorID,
                ),
            )
        }
        context.roster.setActiveEffects(currentEffects, for: effectTarget)
        if !suppressAffixReactions {
            collected.append(contentsOf: CombatTriggerEngine.afterDecayingDoTApplied(
                keyword: keyword,
                to: effectTarget,
                sourceActorID: sourceActorID,
                in: &context,
            ))
        }
        return collected
    }

    package static func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        dealImmediateDamage: Bool,
        suppressAffixReactions: Bool = false,
        durationTurns: Int? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        let resolvedPotency = goldenTouchPotency(potency, sourceActorID: sourceActorID, in: &context)

        var collected: [ActionEvent] = []
        if dealImmediateDamage {
            collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                basePotency: resolvedPotency,
                keyword: .bleed,
                target: effectTarget,
                sourceActorID: sourceActorID,
                in: &context,
            ).events)
        }

        guard !context.interceptDebuff(.bleed(resolvedPotency), on: effectTarget) else { return collected }
        let alreadyBleeding = context.roster.activeEffects(for: effectTarget).contains(where: \.effect.isBleed)
        if alreadyBleeding {
            let sourceTriggers = context.modifiers(for: sourceActorID).triggers
            if sourceTriggers.onBleedAppliedToBleedingExtendTurns > 0 {
                var effects = context.roster.activeEffects(for: effectTarget)
                for index in effects.indices where effects[index].effect.isBleed {
                    effects[index].remainingTurns = min(
                        5,
                        effects[index].remainingTurns + sourceTriggers.onBleedAppliedToBleedingExtendTurns,
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
                    in: &context,
                ).events)
            }
        }

        context.appendEffect(
            .bleed(resolvedPotency),
            to: effectTarget,
            sourceID: sourceActorID,
            remainingTurns: durationTurns ?? (Effect.bleedDoTTurnCount + context.modifiers(for: sourceActorID).bleedDurationBonus),
        )
        if !suppressAffixReactions {
            collected.append(contentsOf: CombatTriggerEngine.afterBleedApplied(
                to: effectTarget,
                sourceActorID: sourceActorID,
                in: &context,
            ))
        }
        return collected
    }

    private static func goldenTouchPotency(
        _ potency: Int,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> Int {
        guard let source = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: source.combatant)
        else { return potency }
        if runtime.goldenTouchActiveThisCard {
            return potency * 2
        }
        guard runtime.pendingDoubleStatusNextCard else { return potency }
        context.roster.mutateRuntime(for: source.combatant) {
            $0.pendingDoubleStatusNextCard = false
            $0.goldenTouchActiveThisCard = true
        }
        return potency * 2
    }
}
