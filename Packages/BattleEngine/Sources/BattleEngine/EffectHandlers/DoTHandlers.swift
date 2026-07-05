import Foundation
import TrinketCore
import TrinketContent

public struct DecayingDoTHandler: BattleEffectHandler {
    public let keyword: Keyword
    public let kind: EffectKind

    public init(keyword: Keyword) {
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

    public func tick(_ active: ActiveEffect, on target: Combatant, in context: inout BattleEngineContext) -> EffectTickOutcome {
        guard matches(active.effect) else { return EffectTickOutcome() }
        let slowPercent = context.modifiers(for: target.id).burnDecaySlowPercent
        let nextPotency = keyword == .burn
            ? active.effect.potencyAfterTick(burnDecaySlowPercent: slowPercent)
            : active.effect.potencyAfterTick()
        if nextPotency > 0 {
            let events = DoTDamage.resolveTick(
                basePotency: nextPotency,
                keyword: keyword,
                target: target,
                sourceActorID: active.sourceActorID,
                in: &context
            ).events
            var updated = active
            updated.effect = effectCase(potency: nextPotency)
            return EffectTickOutcome(events: events, updatedStack: updated)
        }

        var updated = active
        updated.effect = effectCase(potency: 0)
        return EffectTickOutcome(updatedStack: updated, removeAfter: true)
    }

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard stacks.contains(where: \.effect.isDecayingDoT) else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue) active")
    }

    public func apply(
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
        let skipImmediate = action.shouldSkipImmediateDoT(potency: potency, keyword: keyword)
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
        case (.burn, .burn), (.poison, .poison): return true
        default: return false
        }
    }

    private func effectCase(potency: Int) -> Effect {
        switch keyword {
        case .burn: return .burn(potency)
        case .poison: return .poison(potency)
        default: return .burn(potency)
        }
    }
}

public struct BleedHandler: BattleEffectHandler {
    public let kind: EffectKind = .bleed

    public func tick(_ active: ActiveEffect, on target: Combatant, in context: inout BattleEngineContext) -> EffectTickOutcome {
        guard case let .bleed(potency) = active.effect, active.remainingTicks > 0 else {
            return EffectTickOutcome()
        }
        let events = DoTDamage.resolveTick(
            basePotency: potency,
            keyword: .bleed,
            target: target,
            sourceActorID: active.sourceActorID,
            in: &context
        ).events
        var updated = active
        updated.remainingTicks -= 1
        return EffectTickOutcome(
            events: events,
            updatedStack: updated,
            removeAfter: updated.remainingTicks <= 0
        )
    }

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, activeEffect in
            guard case let .bleed(potency) = activeEffect.effect, activeEffect.remainingTicks > 0 else {
                return sum
            }
            return sum + potency
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total) damage")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .bleed(potency) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let bonus = EnemyTraitEngine.bonusBleedPotency(ability: ability, sourceID: source.id, in: context)
        let adjustedPotency = potency + bonus
        let skipImmediate = action.shouldSkipImmediateDoT(potency: adjustedPotency, keyword: .bleed)
        let events = context.applyBleed(
            potency: adjustedPotency,
            to: target,
            sourceActorID: source.id,
            dealImmediateDamage: !skipImmediate
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }
}
