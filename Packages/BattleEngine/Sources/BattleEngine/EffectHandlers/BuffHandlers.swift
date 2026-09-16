import Foundation
import TrinketContent
import TrinketCore

struct ThornsHandler: BattleEffectHandler {
    let kind: EffectKind = .thorns

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = TimedBuffSummary.summedAmount(in: stacks) { effect in
            if case let .thorns(amount) = effect {
                return amount
            }
            return nil
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Thorns: Deals \(total) Thorns damage to the next attacker.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .thorns(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let existing = TimedBuffSummary.summedAmount(in: context.roster.activeEffects(for: target)) { effect in
            if case let .thorns(stacks) = effect {
                return stacks
            }
            return nil
        }
        let total = existing + amount
        return ActiveEffectMutation.replaceAndEmit(
            .thorns(total),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .thorns },
            event: (.thornsApplied, total, .thorns),
        )
    }
}

struct OnHitDamageHandler: BattleEffectHandler {
    let kind: EffectKind = .onHitDamage

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = TimedBuffSummary.maxAmount(in: stacks) { effect in
            if case let .onHitDamage(_, value) = effect {
                return value
            }
            return nil
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
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .onHitDamage(keyword, amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
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
            event: (.wardApplied, amount, keyword),
        )
    }
}

struct MarkedHandler: BattleEffectHandler {
    let kind: EffectKind = .marked

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        let bonus = TimedBuffSummary.maxAmount(in: stacks) { effect in
            if case let .marked(value, _) = effect {
                return value
            }
            return nil
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
                    text: "Marked: The next attack deals +\(bonus) damage and removes Marked; \(BattleTiming.remainingDurationLabel(turns: maxTicks)).",
                )
            }
            return EffectSummary(
                keyword: keyword,
                text: "Marked: The next attack deals +\(bonus) damage and removes Marked.",
            )
        }
        return EffectSummary(keyword: keyword, text: "Marked: The next attack deals extra damage and removes Marked.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .marked(bonus, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            .marked(bonus, durationTurns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .marked },
            event: (.markedApplied, bonus, .physical),
        )
    }
}

struct CriticalChanceBonusHandler: BattleEffectHandler {
    let kind: EffectKind = .criticalChanceBonus

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let percent = TimedBuffSummary.maxPercent(in: stacks) { effect in
            if case let .criticalChanceBonus(value, _) = effect {
                return value
            }
            return nil
        }
        guard percent > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .criticalChanceBonus(_, duration) = effect {
                return duration
            }
            return nil
        }
        if maxTicks > 0 {
            return EffectSummary(
                keyword: keyword,
                text: "Focused: Increases Critical chance by +\(Int(percent * 100))%, \(BattleTiming.remainingDurationLabel(turns: maxTicks)).",
            )
        }
        return EffectSummary(
            keyword: keyword,
            text: "Focused: Increases Critical chance by +\(Int(percent * 100))%.",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .criticalChanceBonus(percent, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            .criticalChanceBonus(percent, durationTurns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .criticalChanceBonus },
            event: (.criticalChanceApplied, Int(percent * 100), .physical),
        )
    }
}

struct RestoreManaOnHitHandler: BattleEffectHandler {
    let kind: EffectKind = .restoreManaOnHit

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = TimedBuffSummary.summedAmount(in: stacks) { effect in
            if case let .restoreManaOnHit(value, _) = effect {
                return value
            }
            return nil
        }
        guard amount > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .restoreManaOnHit(_, duration) = effect {
                return duration
            }
            return nil
        }
        if maxTicks > 0 {
            return EffectSummary(
                keyword: keyword,
                text: "Mana Shield: Restores \(amount) Mana when hit, \(BattleTiming.remainingDurationLabel(turns: maxTicks)).",
            )
        }
        return EffectSummary(
            keyword: keyword,
            text: "Mana Shield: Restores \(amount) Mana when hit.",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
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
            keyword: .mana,
            origin: .direct,
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
        if maxTicks > 0 {
            return EffectSummary(
                keyword: keyword,
                text: "Consecrated: Attacks deal \(overrideKeyword.rawValue) damage (+\(bonus)), \(BattleTiming.remainingDurationLabel(turns: maxTicks)).",
            )
        }
        return EffectSummary(
            keyword: keyword,
            text: "Consecrated: Attacks deal \(overrideKeyword.rawValue) damage (+\(bonus)).",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .damageKeywordOverride(keyword, bonus, durationTurns) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            .damageKeywordOverride(keyword, bonus, durationTurns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .damageKeywordOverride },
            event: (.damageKeywordOverrideApplied, bonus, keyword),
        )
    }
}

struct HemorrhageHandler: BattleEffectHandler {
    let kind: EffectKind = .hemorrhage

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = TimedBuffSummary.maxAmount(in: stacks) { effect in
            if case let .hemorrhage(value) = effect {
                return value
            }
            return nil
        }
        guard amount > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Hemorrhage: Takes \(amount) Bleed damage on next attack.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .hemorrhage(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return ActiveEffectMutation.replaceAndEmit(
            .hemorrhage(amount),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .hemorrhage },
            event: (.hemorrhageApplied, amount, .bleed),
        )
    }
}

struct NextBurnBonusHandler: BattleEffectHandler {
    let kind: EffectKind = .nextBurnBonus

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = TimedBuffSummary.summedAmount(in: stacks) { effect in
            if case let .nextBurnBonus(amount) = effect {
                return amount
            }
            return nil
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Kindled: Next Burn attack deals +\(total) damage.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .nextBurnBonus(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let existing = TimedBuffSummary.summedAmount(in: context.roster.activeEffects(for: target)) { effect in
            if case let .nextBurnBonus(stacks) = effect {
                return stacks
            }
            return nil
        }
        let total = existing + amount
        return ActiveEffectMutation.replaceAndEmit(
            .nextBurnBonus(total),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .nextBurnBonus },
            event: (.nextBurnBonusApplied, total, .burn),
        )
    }
}

struct PartyPhysicalBonusHandler: BattleEffectHandler {
    let kind: EffectKind = .partyPhysicalBonus

    func summary(for _: [ActiveEffect], keyword _: Keyword) -> EffectSummary? {
        nil
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .partyPhysicalBonus(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.resolution.preparePartyPhysicalDamage(amount, sourceID: source.id)
        _ = target
        _ = ability
        return EffectApplyOutcome(events: [], didApply: true)
    }
}
