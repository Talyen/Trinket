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
        return EffectSummary(keyword: keyword, text: "Thorns: Deals \(total) Physical damage to the next attacker.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
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
        let total = existing + amount
        let event = ActiveEffectMutation.replaceAndEmit(
            .thorns(total),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .thorns },
            event: (.thornsApplied, total, .physical)
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct OnHitDamageHandler: BattleEffectHandler {
    let kind: EffectKind = .onHitDamage

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.reduce(0) { maxAmount, active in
            if case let .onHitDamage(_, value) = active.effect {
                return max(maxAmount, value)
            }
            return maxAmount
        }
        guard amount > 0 else { return nil }
        let label = keyword == .freeze ? "Glacial Ward" : "\(keyword.rawValue) Ward"
        return EffectSummary(keyword: keyword, text: "\(label): Deals \(amount) \(keyword.rawValue) damage to the next attacker.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .onHitDamage(keyword, amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = ActiveEffectMutation.replaceAndEmit(
            .onHitDamage(keyword, amount),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: {
                if case let .onHitDamage(existingKeyword, _) = $0 {
                    return existingKeyword == keyword
                }
                return false
            },
            event: (.wardApplied, amount, keyword)
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct MarkedHandler: BattleEffectHandler {
    let kind: EffectKind = .marked

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        let bonus = stacks.reduce(0) { maxBonus, item in
            if case let .marked(value, _) = item.effect {
                return max(maxBonus, value)
            }
            return maxBonus
        }
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .marked(_, duration) = effect {
                return duration
            }
            return nil
        }
        if bonus > 0 {
            if maxTicks > 0 {
                return EffectSummary(
                    keyword: keyword,
                    text: "Marked: Takes +\(bonus) damage from attacks, \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
                )
            }
            return EffectSummary(
                keyword: keyword,
                text: "Marked: Takes +\(bonus) damage from attacks."
            )
        }
        return EffectSummary(keyword: keyword, text: "Marked: Takes extra damage from attacks.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .marked(bonus, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = ActiveEffectMutation.replaceAndEmit(
            .marked(bonus, durationTurns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .marked },
            event: (.markedApplied, bonus, .physical)
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
            text: "Focused: Increases Critical chance by +\(Int(percent * 100))%, \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .criticalChanceBonus(percent, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = ActiveEffectMutation.replaceAndEmit(
            .criticalChanceBonus(percent, durationTurns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .criticalChanceBonus },
            event: (.criticalChanceApplied, Int(percent * 100), .physical)
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct RestoreManaOnHitHandler: BattleEffectHandler {
    let kind: EffectKind = .restoreManaOnHit

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.reduce(0) { sum, active in
            if case let .restoreManaOnHit(value, _) = active.effect {
                return sum + value
            }
            return sum
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
            text: "Mana Shield: Restores \(amount) Mana when hit, \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
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
            text: "Consecrated: Attacks deal \(overrideKeyword.rawValue) damage (+\(bonus)), \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .damageKeywordOverride(keyword, bonus, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = ActiveEffectMutation.replaceAndEmit(
            .damageKeywordOverride(keyword, bonus, durationTurns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .damageKeywordOverride },
            event: (.damageKeywordOverrideApplied, bonus, keyword)
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct HemorrhageHandler: BattleEffectHandler {
    let kind: EffectKind = .hemorrhage

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.reduce(0) { maxAmount, active in
            if case let .hemorrhage(value) = active.effect {
                return max(maxAmount, value)
            }
            return maxAmount
        }
        guard amount > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Hemorrhage: Takes \(amount) Bleed damage on next attack.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .hemorrhage(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = ActiveEffectMutation.replaceAndEmit(
            .hemorrhage(amount),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .hemorrhage },
            event: (.hemorrhageApplied, amount, .bleed)
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
