import Foundation
import TrinketContent
import TrinketCore

/// How a DoT attach behaves, as a two-flag matrix:
/// - `.ability`: immediate damage + application reactions (card/ability play)
/// - `.reaction`: immediate damage, no reactions (mirrors, retaliation)
/// - `.afterHit`: reactions, no immediate damage (post-hit riders)
/// - `.attached`: neither (silent attach: wards, setup)
/// - `.reflection`: neither, and skips bleed tick-existing bonuses
package enum DoTApplication: Equatable {
    case ability
    case reaction
    case afterHit
    case attached
    case reflection

    var dealsImmediateDamage: Bool {
        self == .ability || self == .reaction
    }

    var triggersApplicationReactions: Bool {
        self == .ability || self == .afterHit
    }
}

package enum DoTApplicator {
    /// Single switch for keyword-typed DoT application: burn/poison attach
    /// decaying stacks, bleed attaches bleed stacks. Returns nil for non-DoT
    /// keywords so the caller can fall through to its own handling (usually
    /// nested damage). `durationTurns` applies to bleed only; decaying DoTs
    /// always attach with remainingTurns 0 and ignore it.
    package static func applyDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        durationTurns: Int? = nil,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent]? {
        switch keyword {
        case .bleed:
            applyBleed(
                potency: potency,
                to: effectTarget,
                sourceActorID: sourceActorID,
                application: application,
                durationTurns: durationTurns,
                provenance: provenance,
                in: &context,
            )
        case .burn, .poison:
            applyDecayingDoT(
                keyword: keyword,
                potency: potency,
                to: effectTarget,
                sourceActorID: sourceActorID,
                application: application,
                provenance: provenance,
                in: &context,
            )
        default:
            nil
        }
    }

    package static func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        var collected = immediateDamage(
            keyword: keyword, potency: potency, target: effectTarget,
            sourceActorID: sourceActorID, application: application,
            provenance: provenance, in: &context,
        )

        var currentEffects = context.roster.activeEffects(for: effectTarget)
        let appliedEffect = Effect.decayingDoT(keyword: keyword, potency: potency)
        guard !context.interceptDebuff(appliedEffect, on: effectTarget) else { return collected }
        if let index = currentEffects.firstIndex(where: { $0.effect.keyword == keyword && $0.effect.isDecayingDoT }) {
            let existingPotency = currentEffects[index].effect.potency ?? 0
            currentEffects[index].effect = Effect.decayingDoT(keyword: keyword, potency: existingPotency + potency)
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
        if application.triggersApplicationReactions {
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
        application: DoTApplication,
        durationTurns: Int? = nil,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return [] }

        var collected = immediateDamage(
            keyword: .bleed, potency: potency, target: effectTarget,
            sourceActorID: sourceActorID, application: application,
            provenance: provenance, in: &context,
        )

        guard !context.interceptDebuff(.bleed(potency), on: effectTarget) else { return collected }
        let alreadyBleeding = context.roster.activeEffects(for: effectTarget).contains(where: \.effect.isBleed)
        if alreadyBleeding, application != .reflection {
            let sourceTriggers = context.modifiers(for: sourceActorID).triggers
            if sourceTriggers.bleedApplicationTicksExisting {
                let bleeds = context.roster.activeEffects(for: effectTarget).filter {
                    $0.effect.isBleed && $0.remainingTurns > 0
                }
                for bleed in bleeds {
                    guard context.roster.health(for: effectTarget) > 0 else { break }
                    collected.append(contentsOf: DoTDamage.resolveDamage(
                        basePotency: bleed.effect.potency ?? 0,
                        keyword: .bleed,
                        target: effectTarget,
                        sourceActorID: bleed.sourceActorID ?? sourceActorID,
                        in: &context,
                    ).events)
                }
            }
            if sourceTriggers.onBleedAppliedToBleedingDealDamage > 0 {
                collected.append(contentsOf: DoTDamage.resolveDamage(
                    basePotency: sourceTriggers.onBleedAppliedToBleedingDealDamage,
                    keyword: .bleed,
                    target: effectTarget,
                    sourceActorID: sourceActorID,
                    in: &context,
                ).events)
            }
        }

        context.appendEffect(
            .bleed(potency),
            to: effectTarget,
            sourceID: sourceActorID,
            remainingTurns: durationTurns ?? (Effect.bleedDoTTurnCount + context.modifiers(for: sourceActorID).bleedDurationBonus),
        )
        if application.triggersApplicationReactions {
            collected.append(contentsOf: CombatTriggerEngine.afterBleedApplied(
                to: effectTarget,
                sourceActorID: sourceActorID,
                in: &context,
            ))
        }
        return collected
    }

    private static func immediateDamage(
        keyword: Keyword,
        potency: Int,
        target: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        provenance: DamageProvenance?,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard application.dealsImmediateDamage else { return [] }
        return DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
            provenance: provenance,
            in: &context,
        ).events
    }

    /// Drains decaying stacks without dealing damage. Stays on the applicator
    /// (not the turn handlers): detonation bonuses in the damage pipeline are
    /// the callers.
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
}
