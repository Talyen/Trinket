import Foundation
import TrinketContent
import TrinketCore

struct DecayingDoTHandler: BattleEffectHandler {
    let type: DecayingDoT

    var keyword: Keyword {
        type.keyword
    }

    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard matches(active.effect) else { return [] }
        let progression = DecayingDoTProgression(
            type: type, sourceActorID: active.sourceActorID, target: target, in: context,
        )
        let nextPotency = progression.turnPotency(from: active.effect.potency ?? 0, using: &context.rng)
        var updated = active
        updated.effect = type.effect(potency: nextPotency)
        ActiveEffectMutation.finishTurn(active, replacement: nextPotency > 0 ? updated : nil, on: target, in: &context)
        if nextPotency > 0 {
            var events: [ActionEvent] = []
            for _ in 0 ..< progression.ticksPerTurn {
                let outcome = DoTDamage.resolveDamage(
                    basePotency: nextPotency,
                    keyword: keyword,
                    target: target,
                    sourceActorID: active.sourceActorID,
                    operation: .resolvedPeriodic,
                    in: &context,
                )
                events.append(contentsOf: outcome.events)
                events.append(contentsOf: CombatTriggerEngine.afterDoTTick(
                    keyword: keyword,
                    healthLost: outcome.healthLost,
                    target: target,
                    sourceActorID: active.sourceActorID,
                    in: &context,
                ))
            }
            return events
        }

        return keyword == .poison
            ? CombatTriggerEngine.afterHeroTalentPoisonExpiry(sourceID: active.sourceActorID, target: target, in: &context) : []
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, active in
            if case let .burn(potency) = active.effect, keyword == .burn {
                return sum + potency
            }
            if case let .poison(potency) = active.effect, keyword == .poison {
                return sum + potency
            }
            return sum
        }
        guard total > 0 else { return nil }
        let alias = keyword.statusAlias ?? keyword.rawValue
        return EffectSummary(
            keyword: keyword,
            text: "\(alias): \(total) \(keyword.rawValue) potency. Normally decays before each turn's damage.",
        )
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard let potency = effect.potency, matches(effect) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let events = context.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: source.id,
            application: .ability,
            provenance: context.resolution.damageProvenance(for: source.id),
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func matches(_ effect: Effect) -> Bool {
        effect.kind == type.kind
    }
}

struct BleedHandler: BattleEffectHandler {
    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard case let .bleed(potency) = active.effect, active.remainingTurns > 0 else {
            return []
        }
        let sourceTriggers = active.sourceActorID.map { context.modifiers(for: $0).triggers }
        let isCritical = BattleChance.succeeds(
            probability: sourceTriggers?.bleedTickCritChancePercent ?? 0,
            using: &context.rng,
        )
        let tickOutcome = DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: .bleed,
            target: target,
            sourceActorID: active.sourceActorID,
            guaranteedCritical: isCritical,
            in: &context,
        )
        var events = tickOutcome.events
        events.append(contentsOf: drawCardOnBleedTick(
            active: active,
            sourceTriggers: sourceTriggers,
            target: target,
            in: &context,
        ))

        if let sourceTriggers, sourceTriggers.bleedStripsBlockPerTurn > 0,
           let reduced = DefensePoolEngine.reduce(
               sourceTriggers.bleedStripsBlockPerTurn,
               in: context.roster.activeEffects(for: target),
           ) {
            context.roster.setActiveEffects(reduced.effects, for: target)
        }

        guard var updated = context.roster.activeEffects(for: target).first(where: { $0.id == active.id }) else {
            return events
        }
        if !shouldPreserveBleed(on: target, in: context) {
            updated.remainingTurns -= 1
            let remainingPotency = updated.effect.potency ?? 0
            if updated.remainingTurns == 0, sourceTriggers?.bleedHalvesAfterExpiration == true, remainingPotency > 1 {
                updated.effect = .bleed(remainingPotency / 2)
                updated.remainingTurns = 1
            }
        }
        ActiveEffectMutation.finishTurn(
            active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
        )
        return events
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, activeEffect in
            guard case let .bleed(potency) = activeEffect.effect, activeEffect.remainingTurns > 0 else {
                return sum
            }
            return sum + potency
        }
        guard total > 0 else { return nil }
        let alias = keyword.statusAlias ?? keyword.rawValue
        return EffectSummary(keyword: keyword, text: "\(alias): Takes \(total) \(keyword.rawValue) damage each turn.")
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .bleed(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let bleedsBefore = context.roster.activeEffects(for: target).count(where: \.effect.isBleed)
        let events = DoTApplicator.applyBleed(
            potency: potency,
            to: target,
            sourceActorID: source.id,
            application: .ability,
            provenance: context.resolution.damageProvenance(for: source.id),
            in: &context,
        )
        let didApply = context.roster.activeEffects(for: target).count(where: \.effect.isBleed) > bleedsBefore
        return EffectApplyOutcome(events: events, didApply: didApply)
    }

    private func drawCardOnBleedTick(
        active: ActiveEffect,
        sourceTriggers: CombatTraitTriggers?,
        target _: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard let attackerID = active.sourceActorID,
              let drawChance = sourceTriggers?.bleedTickDrawChancePercent, drawChance > 0,
              BattleChance.succeeds(probability: drawChance, using: &context.rng),
              let source = context.roster.combatant(for: attackerID),
              let owner = context.roster.participant(for: source.combatant), owner.isPartyMember
        else { return [] }
        guard BattleCardCombatEngine.drawFirstCard(matching: .physical, for: owner, context: &context) != nil else { return [] }
        return [context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: source.combatant.name,
            abilityName: CombatTriggerEngine.triggerAbilityName(
                "bleedTickDrawChancePercent",
                for: source.combatant,
                fallback: "Bloodrush",
                in: context,
            ),
            target: source.combatant,
            amount: 1,
            keyword: .physical,
        )]
    }

    private func shouldPreserveBleed(on target: Combatant, in context: BattleState) -> Bool {
        target.role == .enemy
            && context.roster.hasControlStatus(for: target, keyword: .freeze)
            && CombatTriggerEngine.hasLivingPartyTrigger(\.cryostasis, in: context)
    }
}

struct RecurringDamageHandler: BattleEffectHandler {
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .recurringDamage(damageKeyword, potency, _) = active.effect
        else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "\(damageKeyword.rawValue): Deals \(potency) \(damageKeyword.rawValue) damage each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns)).",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .recurringDamage(keyword, potency, turns) = effect, potency > 0, turns > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let application = ActiveEffectMutation.replaceAndEmit(
            .recurringDamage(keyword, potency, turns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: {
                if case let .recurringDamage(existingKeyword, _, _) = $0 {
                    return existingKeyword == keyword
                }
                return false
            },
            event: (.recurringDamageApplied, potency, keyword),
        )
        guard application.didApply else { return application }
        var operation = DamageOperation.periodic
        operation.capturesCardRepeat = context.uniques.card?.repeatDamage == true
            && UniqueCombatEngine.isOrdinaryAction(actorID: source.id, in: context)
        let events = DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: source.id,
            provenance: context.resolution.damageProvenance(for: source.id),
            operation: operation,
            in: &context,
        ).events
        return EffectApplyOutcome(events: application.events + events, didApply: true)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard case let .recurringDamage(keyword, potency, _) = active.effect,
              active.remainingTurns > 0
        else {
            return []
        }
        let sourceID = active.sourceActorID ?? target.id
        let events = DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceID,
            in: &context,
        ).events
        if var updated = context.roster.activeEffects(for: target).first(where: { $0.id == active.id }) {
            updated.remainingTurns -= 1
            ActiveEffectMutation.finishTurn(
                active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
            )
        }
        return events
    }
}
