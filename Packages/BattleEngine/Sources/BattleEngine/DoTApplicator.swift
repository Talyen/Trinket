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
            if sourceTriggers.bleedApplicationTicksExisting {
                let bleeds = context.roster.activeEffects(for: effectTarget).filter {
                    $0.effect.isBleed && $0.remainingTurns > 0
                }
                for bleed in bleeds {
                    guard context.roster.health(for: effectTarget) > 0 else { break }
                    collected.append(contentsOf: DoTDamage.resolveTurnDamage(
                        basePotency: bleed.effect.potency ?? 0,
                        keyword: .bleed,
                        target: effectTarget,
                        sourceActorID: bleed.sourceActorID ?? sourceActorID,
                        in: &context,
                    ).events)
                }
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

    static func consume(
        _ keyword: Keyword,
        upTo amount: Int = .max,
        on target: Combatant,
        in context: inout BattleState,
    ) -> Int {
        guard amount > 0 else { return 0 }
        var remaining = amount
        var effects = context.roster.activeEffects(for: target)
        for index in effects.indices where effects[index].effect.keyword == keyword && effects[index].effect.isDecayingDoT {
            let potency = effects[index].effect.potency ?? 0
            let consumed = min(potency, remaining)
            effects[index].effect = .decayingDoT(keyword: keyword, potency: potency - consumed)
            remaining -= consumed
        }
        effects.removeAll { $0.effect.keyword == keyword && $0.effect.isDecayingDoT && $0.effect.potency == 0 }
        context.roster.setActiveEffects(effects, for: target)
        return amount - remaining
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
