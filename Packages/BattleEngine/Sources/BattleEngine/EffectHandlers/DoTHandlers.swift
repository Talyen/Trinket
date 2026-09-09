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
            var tickPotency = nextPotency
            if keyword == .burn, sourceTriggers?.burnDamageDoubleChancePercent ?? 0 > 0,
               BattleChance.succeeds(probability: sourceTriggers?.burnDamageDoubleChancePercent ?? 0, using: &context.rng) {
                tickPotency *= 2
            }
            tickPotency = doubledFrozenBurnPotency(tickPotency, sourceTriggers: sourceTriggers, target: target, in: &context)
            let tickCount = (keyword == .burn && sourceTriggers?.burnTicksTwicePerTurn == true) ? 2 : 1
            var events: [ActionEvent] = []
            for _ in 0 ..< tickCount {
                let outcome = DoTDamage.resolveTurnDamage(
                    basePotency: tickPotency,
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
            events.append(contentsOf: CombatTriggerEngine.afterDecayingDoTTurn(
                keyword: keyword,
                nextPotency: nextPotency,
                target: target,
                sourceActorID: active.sourceActorID,
                in: &context,
            ))
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
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func matches(_ effect: Effect) -> Bool {
        switch (keyword, effect) {
        case (.burn, .burn), (.poison, .poison): true
        default: false
        }
    }

    private func doubledFrozenBurnPotency(
        _ potency: Int,
        sourceTriggers: CombatTraitTriggers?,
        target: Combatant,
        in context: inout BattleState,
    ) -> Int {
        guard keyword == .burn,
              let doubleVsFrozen = sourceTriggers?.burnDoubleVsFrozenChancePercent,
              doubleVsFrozen > 0, context.roster.hasControlStatus(for: target, keyword: .freeze),
              BattleChance.succeeds(probability: doubleVsFrozen, using: &context.rng)
        else { return potency }
        return potency * 2
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
        let slowPercent = sourceTriggers?.poisonDecaySlowPercent ?? 0
        if slowPercent > 0 {
            let decrease = Effect.poisonDecayAmount(for: potency)
            let adjustedDecrease = CombatRounding.scaled(decrease, multiplier: 1 - min(1, slowPercent))
            return max(0, potency - adjustedDecrease)
        }
        return active.effect.potencyAfterTurn()
    }
}

struct BleedHandler: BattleEffectHandler {
    let kind: EffectKind = .bleed

    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) -> [ActionEvent] {
        guard case let .bleed(potency) = active.effect, active.remainingTurns > 0 else {
            return []
        }
        let sourceTriggers = active.sourceActorID.map { context.modifiers(for: $0).triggers }
        var tickPotency = potency
        if let sourceTriggers, sourceTriggers.bleedTickCritChancePercent > 0,
           BattleChance.succeeds(probability: sourceTriggers.bleedTickCritChancePercent, using: &context.rng) {
            tickPotency *= 2
        }
        let tickOutcome = DoTDamage.resolveTurnDamage(
            basePotency: tickPotency,
            keyword: .bleed,
            target: target,
            sourceActorID: active.sourceActorID,
            in: &context,
        )
        var events = tickOutcome.events
        if let attackerID = active.sourceActorID {
            events.append(contentsOf: DoTMirrorCascade.resolve(
                keyword: .bleed,
                initialHealthLost: tickOutcome.healthLost,
                target: target,
                sourceActorID: attackerID,
                in: &context,
            ))
        }
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
        let drawn = BattleCardCombatEngine.drawCards(count: 1, for: owner, context: &context)
        guard drawn > 0 else { return [] }
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
            amount: drawn,
            keyword: .physical,
        )]
    }

    private func shouldPreserveBleed(on target: Combatant, in context: BattleState) -> Bool {
        target.role == .enemy
            && context.roster.hasControlStatus(for: target, keyword: .freeze)
            && CombatTriggerEngine.livingPartyTriggers(in: context).cryostasis
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
            let outcome = DoTDamage.resolveTurnDamage(
                basePotency: currentAmount,
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
