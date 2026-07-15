import Foundation
import TrinketContent
import TrinketCore

struct HasteHandler: BattleEffectHandler {
    public let kind: EffectKind = .haste

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        // Haste has no combat effect in turn-based card combat (action intervals removed).
        _ = stacks
        _ = keyword
        return nil
    }

    public func apply(
        _ effect: Effect,
        ability _: Ability,
        source _: Combatant,
        target _: Combatant,
        action _: ActionApplyContext,
        in _: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        // No-op: haste previously shortened action intervals, which no longer exist.
        guard case .haste = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        return EffectApplyOutcome(events: [], didApply: false)
    }
}

struct ThornsHandler: BattleEffectHandler {
    public let kind: EffectKind = .thorns

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, active in
            if case let .thorns(_, amount, _) = active.effect {
                return sum + amount
            }
            return sum
        }
        guard total > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .thorns(_, _, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "Thorns: \(total) damage, \(BattleTiming.remainingDurationLabel(ticks: maxTicks)).")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .thorns(keyword, amount, durationTicks) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let strengthBonus = source.primaryStats.strength / 10
        let adjustedAmount = amount + strengthBonus
        context.appendEffect(
            .thorns(keyword, adjustedAmount, durationTicks),
            to: target,
            sourceID: source.id,
            remainingTicks: durationTicks
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: adjustedAmount,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct MarkedHandler: BattleEffectHandler {
    public let kind: EffectKind = .marked

    public func summary(for _: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        EffectSummary(keyword: keyword, text: "Marked")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .marked(bonus, durationTicks) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .marked = $0.effect {
                return true
            }; return false
        }
        context.roster.setActiveEffects(effects, for: target)
        context.appendEffect(.marked(bonus, durationTicks), to: target, sourceID: source.id, remainingTicks: durationTicks)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .markedApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: bonus,
            keyword: .physical
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct CriticalChanceBonusHandler: BattleEffectHandler {
    public let kind: EffectKind = .criticalChanceBonus

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let percent = stacks.reduce(0.0) { maxPercent, active in
            if case let .criticalChanceBonus(value, _) = active.effect {
                return max(maxPercent, value)
            }
            return maxPercent
        }
        guard percent > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .criticalChanceBonus(_, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "Focused: +\(Int(percent * 100))% Critical, \(BattleTiming.remainingDurationLabel(ticks: maxTicks)).")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .criticalChanceBonus(percent, durationTicks) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(.criticalChanceBonus(percent, durationTicks), to: target, sourceID: source.id, remainingTicks: durationTicks)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .criticalChanceApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: Int(percent * 100),
            keyword: .physical
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct RestoreManaOnHitHandler: BattleEffectHandler {
    public let kind: EffectKind = .restoreManaOnHit

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.reduce(0) { maxAmount, active in
            if case let .restoreManaOnHit(value, _) = active.effect {
                return max(maxAmount, value)
            }
            return maxAmount
        }
        guard amount > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .restoreManaOnHit(_, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "Mana Shield: restore \(amount) Mana when hit, \(BattleTiming.remainingDurationLabel(ticks: maxTicks)).")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .restoreManaOnHit(amount, durationTicks) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(.restoreManaOnHit(amount, durationTicks), to: target, sourceID: source.id, remainingTicks: durationTicks)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .manaShieldApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: .mana
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct DamageKeywordOverrideHandler: BattleEffectHandler {
    public let kind: EffectKind = .damageKeywordOverride

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .damageKeywordOverride(overrideKeyword, bonus, _) = active.effect
        else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .damageKeywordOverride(_, _, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(
            keyword: keyword,
            text: "Consecrated: attacks deal \(overrideKeyword.rawValue) (+\(bonus)), \(BattleTiming.remainingDurationLabel(ticks: maxTicks))."
        )
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .damageKeywordOverride(keyword, bonus, durationTicks) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .damageKeywordOverride = $0.effect {
                return true
            }; return false
        }
        context.roster.setActiveEffects(effects, for: target)
        context.appendEffect(
            .damageKeywordOverride(keyword, bonus, durationTicks),
            to: target,
            sourceID: source.id,
            remainingTicks: durationTicks
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .damageKeywordOverrideApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: bonus,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
