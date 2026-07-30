import Foundation
import TrinketContent
import TrinketCore

struct ThornsHandler: BattleEffectHandler {
    let kind: EffectKind = .thorns

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, active in
            if case let .thorns(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Thorns: \(total) (until next hit).")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .thorns(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let existing = context.roster.activeEffects(for: target).reduce(0) { sum, active in
            if case let .thorns(stacks) = active.effect {
                return sum + stacks
            }
            return sum
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .thorns = $0 {
                return true
            }
            return false
        }
        let total = existing + amount
        context.appendEffect(
            .thorns(total),
            to: target,
            sourceID: source.id,
            remainingTurns: 0
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .thornsApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: total,
            keyword: .physical
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct FreezeOnHitHandler: BattleEffectHandler {
    let kind: EffectKind = .freezeOnHit

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.reduce(0) { maxAmount, active in
            if case let .freezeOnHit(value) = active.effect {
                return max(maxAmount, value)
            }
            return maxAmount
        }
        guard amount > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Glacial Ward: \(amount) Freeze (until next hit).")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .freezeOnHit(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .freezeOnHit = $0 {
                return true
            }
            return false
        }
        context.appendEffect(.freezeOnHit(amount), to: target, sourceID: source.id, remainingTurns: 0)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .controlApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: .freeze
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct MarkedHandler: BattleEffectHandler {
    let kind: EffectKind = .marked

    func summary(for _: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        EffectSummary(keyword: keyword, text: "Marked")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .marked(bonus, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .marked = $0 {
                return true
            }
            return false
        }
        context.appendEffect(.marked(bonus, durationTurns), to: target, sourceID: source.id, remainingTurns: durationTurns)
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
    let kind: EffectKind = .criticalChanceBonus

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let percent = stacks.reduce(0.0) { maxPercent, active in
            if case let .criticalChanceBonus(value, _) = active.effect {
                return max(maxPercent, value)
            }
            return maxPercent
        }
        guard percent > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .criticalChanceBonus(_, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(
            keyword: keyword,
            text: "Focused: +\(Int(percent * 100))% Critical, \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .criticalChanceBonus(percent, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        // Refresh replaces prior Focused stacks so combat chance matches the summary's max.
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .criticalChanceBonus = $0 {
                return true
            }
            return false
        }
        context.appendEffect(.criticalChanceBonus(percent, durationTurns), to: target, sourceID: source.id, remainingTurns: durationTurns)
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
    let kind: EffectKind = .restoreManaOnHit

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.reduce(0) { maxAmount, active in
            if case let .restoreManaOnHit(value, _) = active.effect {
                return max(maxAmount, value)
            }
            return maxAmount
        }
        guard amount > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .restoreManaOnHit(_, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(
            keyword: keyword,
            text: "Mana Shield: restore \(amount) Mana when hit, \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .restoreManaOnHit(amount, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(.restoreManaOnHit(amount, durationTurns), to: target, sourceID: source.id, remainingTurns: durationTurns)
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
    let kind: EffectKind = .damageKeywordOverride

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .damageKeywordOverride(overrideKeyword, bonus, _) = active.effect
        else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .damageKeywordOverride(_, _, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(
            keyword: keyword,
            text: "Consecrated: attacks deal \(overrideKeyword.rawValue) (+\(bonus)), \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .damageKeywordOverride(keyword, bonus, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .damageKeywordOverride = $0 {
                return true
            }
            return false
        }
        context.appendEffect(
            .damageKeywordOverride(keyword, bonus, durationTurns),
            to: target,
            sourceID: source.id,
            remainingTurns: durationTurns
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
