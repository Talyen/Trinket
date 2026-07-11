import Foundation
import TrinketContent
import TrinketCore

public struct ShieldHandler: BattleEffectHandler {
    public let kind: EffectKind = .shield

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, effect in
            if case let .shield(_, buffer) = effect.effect {
                return sum + buffer
            }
            return sum
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total).")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .shield(keyword, buffer) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .shield(adjustedKeyword, adjustedBuffer) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        DefensePoolEngine.addBlock(adjustedBuffer, to: target, keyword: adjustedKeyword, in: &context)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: adjustedBuffer,
            keyword: adjustedKeyword
        )
        var events = [event]
        events.append(contentsOf: CombatReactionEngine.afterBlockGained(by: target, in: &context))
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

public struct MitigationHandler: BattleEffectHandler {
    public let kind: EffectKind = .mitigation

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, effect in
            if case let .mitigation(_, points) = effect.effect {
                return sum + points
            }
            return sum
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total).")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .mitigation(keyword, points) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .mitigation(adjustedKeyword, adjustedPoints) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        DefensePoolEngine.addArmor(adjustedPoints, to: target, keyword: adjustedKeyword, in: &context)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .mitigationApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: adjustedPoints,
            keyword: adjustedKeyword
        )
        var events = [event]
        events.append(contentsOf: CombatReactionEngine.afterArmorGained(by: target, in: &context))
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

public struct LeechHandler: BattleEffectHandler {
    public let kind: EffectKind = .leech

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
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

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .leech(keyword, percent, durationTicks) = effect else {
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

public struct NextHolyStrikeHandler: BattleEffectHandler {
    public let kind: EffectKind = .nextHolyStrike

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(keyword: keyword, text: "Next Holy Strike ready.")
    }

    public func apply(
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
