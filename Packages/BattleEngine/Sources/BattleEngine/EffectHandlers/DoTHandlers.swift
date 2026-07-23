import Foundation
import TrinketContent
import TrinketCore

struct DecayingDoTHandler: BattleEffectHandler {
    let keyword: Keyword
    let kind: EffectKind

    init(keyword: Keyword) {
        self.keyword = keyword
        switch keyword {
        case .burn:
            kind = .burn
        case .poison:
            kind = .poison
        default:
            kind = .burn
        }
    }

    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleEngineContext) -> EffectTurnOutcome {
        guard matches(active.effect) else { return EffectTurnOutcome() }
        let slowPercent = context.modifiers(for: target.id).burnDecaySlowPercent
        let nextPotency: Int = if keyword == .burn {
            active.effect.potencyAfterTurn(burnDecaySlowPercent: slowPercent)
        } else if keyword == .poison {
            poisonPotencyAfterTurn(active, in: &context)
        } else {
            active.effect.potencyAfterTurn()
        }
        if nextPotency > 0 {
            let events = DoTDamage.resolveTurnDamage(
                basePotency: nextPotency,
                keyword: keyword,
                target: target,
                sourceActorID: active.sourceActorID,
                in: &context
            ).events
            var updated = active
            updated.effect = effectCase(potency: nextPotency)
            return EffectTurnOutcome(events: events, updatedStack: updated)
        }

        var updated = active
        updated.effect = effectCase(potency: 0)
        return EffectTurnOutcome(updatedStack: updated, removeAfter: true)
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard stacks.contains(where: \.effect.isDecayingDoT) else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue) active")
    }

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        action: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard let potency = effect.potency, matches(effect) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        guard context.roster.health(for: target) > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let skipImmediate = action.shouldSkipImmediateDoT(keyword: keyword)
        let events = context.applyDecayingDoT(
            keyword: keyword,
            potency: potency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func matches(_ effect: Effect) -> Bool {
        switch (keyword, effect) {
        case (.burn, .burn), (.poison, .poison): true
        default: false
        }
    }

    private func effectCase(potency: Int) -> Effect {
        switch keyword {
        case .burn: .burn(potency)
        case .poison: .poison(potency)
        default: .burn(potency)
        }
    }

    private func poisonPotencyAfterTurn(
        _ active: ActiveEffect,
        in context: inout BattleEngineContext
    ) -> Int {
        guard case let .poison(potency) = active.effect else {
            return active.effect.potencyAfterTurn()
        }
        let chance: Double = if let sourceActorID = active.sourceActorID {
            context.modifiers(for: sourceActorID).poisonDecayIncreaseChance
        } else {
            0
        }
        if chance > 0, Double.random(in: 0 ... 1, using: &context.rng) < chance {
            return potency + 1
        }
        return active.effect.potencyAfterTurn()
    }
}

struct BleedHandler: BattleEffectHandler {
    let kind: EffectKind = .bleed

    func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleEngineContext) -> EffectTurnOutcome {
        guard case let .bleed(potency) = active.effect, active.remainingTurns > 0 else {
            return EffectTurnOutcome()
        }
        let events = DoTDamage.resolveTurnDamage(
            basePotency: potency,
            keyword: .bleed,
            target: target,
            sourceActorID: active.sourceActorID,
            in: &context
        ).events
        var updated = active
        updated.remainingTurns -= 1
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
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total) damage")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .bleed(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        guard context.roster.health(for: target) > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let bonus = EnemyTraitEngine.bonusBleedPotency(ability: ability, sourceID: source.id, in: context)
        let adjustedPotency = potency + bonus
        let skipImmediate = action.shouldSkipImmediateDoT(keyword: .bleed)
        let events = DoTApplicator.applyBleed(
            potency: adjustedPotency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate,
            in: &context
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }
}
