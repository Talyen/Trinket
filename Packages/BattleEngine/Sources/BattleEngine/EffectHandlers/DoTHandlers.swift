import Foundation
import TrinketContent
import TrinketCore

struct DecayingDoTHandler: BattleEffectHandler {
    let keyword: Keyword
    let kind: EffectKind

    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard matches(active.effect) else { return [] }
        let sourceTriggers = active.sourceActorID.map { context.modifiers(for: $0).triggers }
        let slowPercent = sourceTriggers?.burnDecaySlowPercent ?? 0
        let nextPotency: Int
        if keyword == .burn {
            let decayed = active.effect.potencyAfterTurn(burnDecaySlowPercent: slowPercent)
            if let sourceTriggers, sourceTriggers.burnIncreaseChancePercent > 0,
               BattleChance.succeeds(probability: sourceTriggers.burnIncreaseChancePercent, using: &context.rng),
               let potency = active.effect.potency {
                nextPotency = potency + 1
            } else {
                nextPotency = decayed
            }
        } else if keyword == .poison {
            nextPotency = poisonPotencyAfterTurn(active, sourceTriggers: sourceTriggers, in: &context)
        } else {
            nextPotency = active.effect.potencyAfterTurn()
        }
        var updated = active
        updated.effect = Effect.decayingDoT(keyword: keyword, potency: nextPotency)
        ActiveEffectMutation.finishTurn(active, replacement: nextPotency > 0 ? updated : nil, on: target, in: &context)
        if nextPotency > 0 {
            let tickCount = (keyword == .burn && sourceTriggers?.burnTicksTwicePerTurn == true) ? 2 : 1
            var events: [ActionEvent] = []
            for _ in 0 ..< tickCount {
                let outcome = DoTDamage.resolveDamage(
                    basePotency: nextPotency,
                    keyword: keyword,
                    target: target,
                    sourceActorID: active.sourceActorID,
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
        let decayDescription = keyword == .burn ? "decaying over time" : "decaying slowly"
        let alias = keyword.statusAlias ?? keyword.rawValue
        return EffectSummary(
            keyword: keyword,
            text: "\(alias): Takes \(total) \(keyword.rawValue) damage each turn, \(decayDescription).",
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
        switch (keyword, effect) {
        case (.burn, .burn), (.poison, .poison): true
        default: false
        }
    }

    private func poisonPotencyAfterTurn(
        _ active: ActiveEffect,
        sourceTriggers: CombatTraitTriggers?,
        in context: inout BattleState,
    ) -> Int {
        guard case let .poison(potency) = active.effect else {
            return active.effect.potencyAfterTurn()
        }
        let chance: Double = if let sourceActorID = active.sourceActorID {
            context.modifiers(for: sourceActorID).triggers.poisonDecayIncreaseChance
        } else {
            0
        }
        if BattleChance.succeeds(probability: chance, using: &context.rng) {
            return potency + 1
        }
        return active.effect.potencyAfterTurn(poisonDecaySlowPercent: sourceTriggers?.poisonDecaySlowPercent ?? 0)
    }
}

struct BleedHandler: BattleEffectHandler {
    let kind: EffectKind = .bleed

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

enum DoTMirrorCascade {
    static let maxChainDepth = ReactionScope.maxDoTMirrorChainDepth

    static func resolve(
        keyword: Keyword,
        initialHealthLost: Int,
        target: Combatant,
        sourceActorID: String,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        guard initialHealthLost > 0, context.resolution.depth(.dotMirror) == 0 else { return [] }
        context.resolution.enter(.dotMirror)
        defer { context.resolution.leave(.dotMirror) }
        var events: [ActionEvent] = []
        var currentKeyword = keyword
        var currentAmount = initialHealthLost
        for _ in 0 ..< maxChainDepth {
            guard currentAmount > 0, context.roster.health(for: target) > 0 else { break }
            let triggers = context.modifiers(for: sourceActorID).triggers
            let chance: Double = switch currentKeyword {
            case .burn: triggers.burnProcsBleedChancePercent
            case .bleed: triggers.bleedProcsBurnChancePercent
            default: 0
            }
            guard chance > 0, BattleChance.succeeds(probability: chance, using: &context.rng) else { break }
            let mirrored: Keyword = currentKeyword == .burn ? .bleed : .burn
            let outcome = DoTDamage.resolveDamage(
                basePotency: 1,
                keyword: mirrored,
                target: target,
                sourceActorID: sourceActorID,
                in: &context,
            )
            events.append(contentsOf: outcome.events)
            currentKeyword = mirrored
            currentAmount = outcome.healthLost
        }
        return events
    }
}

private func isDetonatableDoT(_ effect: Effect, keyword: Keyword) -> Bool {
    effect.keyword == keyword && (effect.isDecayingDoT || effect.isBleed)
}

struct MultiplyDoTHandler: BattleEffectHandler {
    let kind: EffectKind = .multiplyDoT

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .multiplyDoT(keyword, factor) = effect, factor > 1 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var effects = context.roster.activeEffects(for: target)
        guard let index = effects.firstIndex(where: {
            isDetonatableDoT($0.effect, keyword: keyword)
        }) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let potency = effects[index].effect.potency ?? 0
        let multiplied = potency * factor
        switch keyword {
        case .burn:
            effects[index].effect = .burn(multiplied)
        case .poison:
            effects[index].effect = .poison(multiplied)
        case .bleed:
            effects[index].effect = .bleed(multiplied)
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.roster.setActiveEffects(effects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .dotAmplified,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: multiplied,
            keyword: keyword,
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct DetonateDoTHandler: BattleEffectHandler {
    let kind: EffectKind = .detonateDoT

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .detonateDoT(keyword, factor) = effect, factor > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        guard context.resolution.depth(.detonation) == 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.resolution.enter(.detonation)
        defer { context.resolution.leave(.detonation) }
        var effects = context.roster.activeEffects(for: target)
        let matching = effects.filter {
            isDetonatableDoT($0.effect, keyword: keyword)
        }
        guard !matching.isEmpty else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        effects.removeAll {
            isDetonatableDoT($0.effect, keyword: keyword)
        }
        context.roster.setActiveEffects(effects, for: target)
        var events: [ActionEvent] = []
        for active in matching {
            events.append(contentsOf: detonate(active, factor: factor, source: source, target: target, in: &context))
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func detonate(
        _ active: ActiveEffect,
        factor: Int,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        if active.effect.isBleed {
            var amplified = active
            amplified.effect = .bleed((active.effect.potency ?? 0) * factor)
            return CombatTriggerEngine.detonateBleedStacks(
                [amplified], on: target, sourceActorID: source.id,
                provenance: context.resolution.damageProvenance(for: source.id), in: &context,
            )
        }
        let sourceTriggers = active.sourceActorID.map { context.modifiers(for: $0).triggers }
        let slowBurn = sourceTriggers?.burnDecaySlowPercent ?? 0
        let tickCount = active.keyword == .burn && sourceTriggers?.burnTicksTwicePerTurn == true ? 2 : 1
        var remaining = active.effect
        var events: [ActionEvent] = []
        while context.roster.health(for: target) > 0 {
            let next = remaining.potencyAfterTurn(
                burnDecaySlowPercent: slowBurn, poisonDecaySlowPercent: sourceTriggers?.poisonDecaySlowPercent ?? 0,
            )
            guard next > 0 else { break }
            remaining = .decayingDoT(keyword: active.keyword, potency: next)
            for _ in 0 ..< tickCount where context.roster.health(for: target) > 0 {
                events.append(contentsOf: DoTDamage.resolveDamage(
                    basePotency: next * factor,
                    keyword: active.keyword,
                    target: target,
                    sourceActorID: source.id,
                    provenance: context.resolution.damageProvenance(for: source.id),
                    in: &context,
                ).events)
            }
        }
        return events
    }
}

struct RecurringDamageHandler: BattleEffectHandler {
    let kind: EffectKind = .recurringDamage

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
        if UniqueCombatEngine.isOrdinaryAction(actorID: source.id, in: context) {
            context.uniques.card?.damageRequests.append(.doTTick(
                amount: potency,
                target: target,
                keyword: keyword,
                sourceActorID: source.id,
            ))
        }
        let events = DoTDamage.resolveDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: source.id,
            provenance: context.resolution.damageProvenance(for: source.id),
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
