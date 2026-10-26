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
    /// decaying stacks, bleed attaches bleed stacks. Returns whether the keyword
    /// was handled so callers can fall through for non-DoT damage (usually
    /// nested damage). `durationTurns` applies to bleed only; decaying DoTs
    /// always attach with remainingTurns 0 and ignore it.
    @discardableResult
    package static func applyDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication = .reaction,
        durationTurns: Int? = nil,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) async -> Bool {
        switch keyword {
        case .bleed:
            await applyBleed(
                potency: potency,
                to: effectTarget,
                sourceActorID: sourceActorID,
                application: application,
                durationTurns: durationTurns,
                provenance: provenance,
                in: &context,
            )
            return true
        case .burn, .poison:
            await applyDecayingDoT(
                keyword: keyword,
                potency: potency,
                to: effectTarget,
                sourceActorID: sourceActorID,
                application: application,
                provenance: provenance,
                in: &context,
            )
            return true
        default:
            return false
        }
    }

    @discardableResult
    package static func applyDecayingDoT(
        keyword: Keyword,
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) async -> Bool {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return false }

        let outcome = await immediateDamage(
            keyword: keyword, potency: potency, target: effectTarget,
            sourceActorID: sourceActorID, application: application,
            provenance: provenance, in: &context,
        )
        let didDamage = outcome.healthLost > 0
        let appliedPotency = application.dealsImmediateDamage ? outcome.healthLost : potency
        guard appliedPotency > 0, context.roster.health(for: effectTarget) > 0 else { return didDamage }

        let appliedEffect = Effect.decayingDoT(keyword: keyword, potency: appliedPotency)
        guard !context.interceptDebuff(appliedEffect, on: effectTarget) else { return didDamage }
        let existingIndex = context.roster.activeEffects(for: effectTarget).firstIndex {
            $0.effect.keyword == keyword && $0.effect.isDecayingDoT
        }
        let newEffectID = existingIndex == nil ? context.consumeNextEffectID() : nil
        context.roster.mutateEffects(for: effectTarget) { effects in
            if let index = existingIndex {
                effects[index].effect = .decayingDoT(
                    keyword: keyword,
                    potency: SaturatedArithmetic.saturatingAdd(effects[index].effect.potency ?? 0, appliedPotency),
                )
            } else if let newEffectID {
                effects.append(ActiveEffect(
                    id: newEffectID, effect: appliedEffect,
                    remainingTurns: 0, sourceActorID: sourceActorID,
                ))
            }
        }
        if application.triggersApplicationReactions {
            CombatTriggerEngine.afterDecayingDoTApplied(keyword: keyword, to: effectTarget, sourceActorID: sourceActorID, in: &context)
        }
        return true
    }

    @discardableResult
    package static func applyBleed(
        potency: Int,
        to effectTarget: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        durationTurns: Int? = nil,
        provenance: DamageProvenance? = nil,
        in context: inout BattleState,
    ) async -> Bool {
        guard context.roster.health(for: effectTarget) > 0, potency > 0 else { return false }

        let outcome = await immediateDamage(
            keyword: .bleed, potency: potency, target: effectTarget,
            sourceActorID: sourceActorID, application: application,
            provenance: provenance, in: &context,
        )
        var didDamage = outcome.healthLost > 0

        guard context.roster.health(for: effectTarget) > 0 else { return didDamage }
        guard !context.interceptDebuff(.bleed(potency), on: effectTarget) else { return didDamage }
        let alreadyBleeding = context.roster.activeEffects(for: effectTarget).contains(where: \.effect.isBleed)
        if alreadyBleeding, application != .reflection {
            let sourceTriggers = context.modifiers(for: sourceActorID).triggers
            if sourceTriggers.bleedApplicationTicksExisting {
                let bleeds = context.roster.activeEffects(for: effectTarget).filter {
                    $0.effect.isBleed && $0.remainingTurns > 0
                }
                for bleed in bleeds {
                    guard context.roster.health(for: effectTarget) > 0 else { break }
                    let outcome = await DoTDamage.resolveDamage(
                        basePotency: bleed.effect.potency ?? 0,
                        keyword: .bleed,
                        target: effectTarget,
                        sourceActorID: bleed.sourceActorID ?? sourceActorID,
                        in: &context,
                    )
                    didDamage = didDamage || outcome.healthLost > 0
                }
            }
            if sourceTriggers.onBleedAppliedToBleedingDealDamage > 0 {
                let outcome = await DoTDamage.resolveDamage(
                    basePotency: sourceTriggers.onBleedAppliedToBleedingDealDamage,
                    keyword: .bleed,
                    target: effectTarget,
                    sourceActorID: sourceActorID,
                    in: &context,
                )
                didDamage = didDamage || outcome.healthLost > 0
            }
        }

        let sourceProfile = context.modifiers(for: sourceActorID)
        guard context.roster.health(for: effectTarget) > 0 else { return didDamage }
        let poisonDurationBonus = application != .reflection && context.roster.hasAffliction(.poison, on: effectTarget)
            ? sourceProfile.triggers.bleedDurationVsPoisonedBonus : 0
        let stored = context.insertEffect(
            .bleed(potency),
            to: effectTarget,
            sourceID: sourceActorID,
            remainingTurns: SaturatedArithmetic.saturatingAdd(
                durationTurns ?? SaturatedArithmetic.saturatingAdd(Effect.bleedDoTTurnCount, sourceProfile.bleedDurationBonus),
                poisonDurationBonus,
            ),
        )
        return stored || didDamage
    }

    private static func immediateDamage(
        keyword: Keyword,
        potency: Int,
        target: Combatant,
        sourceActorID: String,
        application: DoTApplication,
        provenance: DamageProvenance?,
        in context: inout BattleState,
    ) async -> CombatOutcome {
        guard application.dealsImmediateDamage else { return .empty }
        return await DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceActorID,
            provenance: provenance,
            in: &context,
        )
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
        guard context.roster.activeEffects(for: target).contains(where: {
            $0.effect.keyword == keyword && $0.effect.isDecayingDoT
        }) else { return 0 }
        context.roster.mutateEffects(for: target) { effects in
            ActiveEffectMutation.update(&effects) { active in
                guard active.keyword == keyword, active.effect.isDecayingDoT else { return active }
                let potency = active.effect.potency ?? 0
                let consumed = remaining > 0 ? min(potency, remaining) : 0
                remaining -= consumed
                let retained = potency - consumed
                guard retained != 0 else { return nil }
                guard consumed != 0 else { return active }
                var updated = active
                updated.effect = .decayingDoT(keyword: keyword, potency: retained)
                return updated
            }
        }
        return amount - remaining
    }
}
