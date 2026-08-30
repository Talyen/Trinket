import Foundation
import TrinketContent
import TrinketCore

struct DecayingDoTHandler: BattleEffectHandler {
    let keyword: Keyword
    let kind: EffectKind

    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) -> EffectTurnOutcome {
        guard matches(active.effect) else { return EffectTurnOutcome() }
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
        if nextPotency > 0 {
            var tickPotency = nextPotency
            if keyword == .burn, sourceTriggers?.burnDamageDoubleChancePercent ?? 0 > 0,
               BattleChance.succeeds(probability: sourceTriggers?.burnDamageDoubleChancePercent ?? 0, using: &context.rng) {
                tickPotency *= 2
            }
            let tickCount = (keyword == .burn && sourceTriggers?.burnTicksTwicePerTurn == true) ? 2 : 1
            var events: [ActionEvent] = []
            for _ in 0 ..< tickCount {
                let outcome = DoTDamage.resolveTurnDamage(
                    basePotency: tickPotency,
                    keyword: keyword,
                    target: target,
                    sourceActorID: active.sourceActorID,
                    in: &context
                )
                events.append(contentsOf: outcome.events)
                events.append(contentsOf: CombatTriggerEngine.afterDoTTick(
                    keyword: keyword,
                    healthLost: outcome.healthLost,
                    target: target,
                    sourceActorID: active.sourceActorID,
                    in: &context
                ))
            }
            events.append(contentsOf: CombatTriggerEngine.afterDecayingDoTTurn(
                keyword: keyword,
                nextPotency: nextPotency,
                target: target,
                sourceActorID: active.sourceActorID,
                in: &context
            ))
            var updated = active
            updated.effect = Effect.decayingDoT(keyword: keyword, potency: nextPotency)
            return EffectTurnOutcome(events: events, updatedStack: updated)
        }

        var updated = active
        updated.effect = Effect.decayingDoT(keyword: keyword, potency: 0)
        return EffectTurnOutcome(updatedStack: updated, removeAfter: true)
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
            text: "\(alias): Takes \(total) \(keyword.rawValue) damage each turn, \(decayDescription)."
        )
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard let potency = effect.potency, matches(effect) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let events = context.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: true
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
        in context: inout BattleState
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

    // swiftlint:disable:next function_body_length
    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) -> EffectTurnOutcome {
        guard case let .bleed(potency) = active.effect, active.remainingTurns > 0 else {
            return EffectTurnOutcome()
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
            in: &context
        )
        var events = tickOutcome.events
        if let attackerID = active.sourceActorID {
            events.append(contentsOf: DoTMirrorCascade.resolve(
                keyword: .bleed,
                initialHealthLost: tickOutcome.healthLost,
                target: target,
                sourceActorID: attackerID,
                in: &context
            ))
        }

        if let sourceTriggers, sourceTriggers.onBleedDamageNextBasicGuaranteedCrit,
           let attackerID = active.sourceActorID,
           let caster = context.roster.combatant(for: attackerID) {
            context.roster.mutateRuntime(for: caster.combatant) { $0.pendingBasicGuaranteedCrit = true }
        }

        if let sourceTriggers, let attackerID = active.sourceActorID {
            if sourceTriggers.bleedStripsBlockPerTurn > 0,
               let reduced = DefensePoolEngine.reduce(
                   sourceTriggers.bleedStripsBlockPerTurn,
                   in: context.roster.activeEffects(for: target)
               ) {
                context.roster.setActiveEffects(reduced.effects, for: target)
            }
            if sourceTriggers.onBleedDamageHealSelf > 0,
               let caster = context.roster.combatant(for: attackerID) {
                events.append(contentsOf: HealingEngine.resolveHeal(
                    HealRequest(amount: sourceTriggers.onBleedDamageHealSelf, target: caster.combatant, sourceActorID: attackerID),
                    in: &context
                ).events)
            }
            if sourceTriggers.onBleedDamagePoisonTick > 0 {
                let poisonPotency = context.roster.activeEffects(for: target).reduce(0) { sum, active in
                    if case let .poison(potency) = active.effect, active.remainingTurns > 0 {
                        return sum + potency
                    }
                    return sum
                }
                if poisonPotency > 0 {
                    events.append(contentsOf: DoTDamage.resolveTurnDamage(
                        basePotency: poisonPotency,
                        keyword: .poison,
                        target: target,
                        sourceActorID: attackerID,
                        in: &context
                    ).events)
                }
            }
        }

        var updated = active
        if !BoonCombatEngine.preservesBleed(on: target, in: context) {
            updated.remainingTurns -= 1
        }
        return EffectTurnOutcome(
            events: events,
            updatedStack: updated,
            removeAfter: updated.remainingTurns <= 0
        )
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
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .bleed(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let bleedsBefore = context.roster.activeEffects(for: target).count(where: \.effect.isBleed)
        let events = DoTApplicator.applyBleed(
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: true,
            in: &context
        )
        let didApply = context.roster.activeEffects(for: target).count(where: \.effect.isBleed) > bleedsBefore
        return EffectApplyOutcome(events: events, didApply: didApply)
    }
}

enum DoTMirrorCascade {
    static let maxChainDepth = ReactionScope.maxDoTMirrorChainDepth

    static func resolve(
        keyword: Keyword,
        initialHealthLost: Int,
        target: Combatant,
        sourceActorID: String,
        in context: inout BattleState
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
                in: &context
            )
            events.append(contentsOf: outcome.events)
            currentKeyword = mirrored
            currentAmount = outcome.healthLost
        }
        return events
    }
}
