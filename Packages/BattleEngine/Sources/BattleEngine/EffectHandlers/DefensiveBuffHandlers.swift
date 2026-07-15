import Foundation
import TrinketContent
import TrinketCore

/// Shared handler for shield (block) and mitigation (armor) pool gains.
struct DefensePoolBuffHandler: BattleEffectHandler {
    enum Pool: Sendable {
        case shield
        case mitigation

        var kind: EffectKind {
            switch self {
            case .shield: .shield
            case .mitigation: .mitigation
            }
        }

        var appliedEffectKind: ActionEvent.EffectKind {
            switch self {
            case .shield: .shieldApplied
            case .mitigation: .mitigationApplied
            }
        }
    }

    let pool: Pool
    var kind: EffectKind {
        pool.kind
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, active in
            switch (pool, active.effect) {
            case let (.shield, .shield(_, value)),
                 let (.mitigation, .mitigation(_, value)):
                sum + value
            default:
                sum
            }
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total).")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        let keyword: Keyword
        let amount: Int
        switch (pool, adjusted) {
        case let (.shield, .shield(adjustedKeyword, adjustedAmount)):
            keyword = adjustedKeyword
            amount = adjustedAmount
        case let (.mitigation, .mitigation(adjustedKeyword, adjustedAmount)):
            keyword = adjustedKeyword
            amount = adjustedAmount
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }

        switch pool {
        case .shield:
            DefensePoolEngine.addBlock(amount, to: target, keyword: keyword, in: &context)
        case .mitigation:
            DefensePoolEngine.addArmor(amount, to: target, keyword: keyword, in: &context)
        }

        let event = context.nextEvent(
            kind: .effect,
            effectKind: pool.appliedEffectKind,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: keyword
        )
        var events = [event]
        switch pool {
        case .shield:
            events.append(contentsOf: CombatReactionEngine.afterBlockGained(by: target, in: &context))
        case .mitigation:
            events.append(contentsOf: CombatReactionEngine.afterArmorGained(by: target, in: &context))
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

struct LeechHandler: BattleEffectHandler {
    let kind: EffectKind = .leech

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let percent = stacks.reduce(0.0) { maxPercent, effect in
            if case let .leech(_, value, _) = effect.effect {
                return max(maxPercent, value)
            }
            return maxPercent
        }
        guard percent > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .leech(_, _, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(
            keyword: keyword,
            text: "\(keyword.rawValue): \(Int(percent * 100))% leech, \(BattleTiming.remainingDurationLabel(ticks: maxTicks))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case .leech = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .leech(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let wisdomTicks = source.primaryStats.wisdom / 20
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .leech = $0.effect {
                return true
            }; return false
        }
        context.roster.setActiveEffects(effects, for: target)
        context.appendEffect(
            .leech(adjustedKeyword, adjustedPercent, adjustedDuration),
            to: target,
            sourceID: source.id,
            remainingTicks: adjustedDuration + wisdomTicks
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .leechApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: Int(adjustedPercent * 100),
            keyword: adjustedKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct NextHolyStrikeHandler: BattleEffectHandler {
    let kind: EffectKind = .nextHolyStrike

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(keyword: keyword, text: "Next Holy Strike ready.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case .nextHolyStrike = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll {
            if case .nextHolyStrike = $0.effect {
                return true
            }; return false
        }
        context.roster.setActiveEffects(effects, for: target)
        context.appendEffect(
            .nextHolyStrike,
            to: target,
            sourceID: source.id,
            remainingTicks: 0
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .nextHolyStrikeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: .holy
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
