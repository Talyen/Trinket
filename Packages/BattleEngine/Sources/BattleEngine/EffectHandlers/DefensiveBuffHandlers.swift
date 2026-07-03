import Foundation
import TrinketCore
import TrinketContent

public struct ShieldHandler: BattleEffectHandler {
    public let kind: EffectKind = .shield

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, effect in
            if case let .shield(_, buffer, _) = effect.effect { return sum + buffer }
            return sum
        }
        guard total > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .shield(_, _, duration) = effect { return duration }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total) buffer, \(maxTicks) ticks left.")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .shield(keyword, buffer, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .shield(adjustedKeyword, adjustedBuffer, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(
            .shield(adjustedKeyword, adjustedBuffer, adjustedDuration),
            to: target,
            sourceID: source.id,
            remainingTicks: adjustedDuration
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: adjustedBuffer,
            keyword: adjustedKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

public struct MitigationHandler: BattleEffectHandler {
    public let kind: EffectKind = .mitigation

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let totalPct = stacks.reduce(0.0) { sum, effect in
            if case let .mitigation(_, percent, _) = effect.effect { return sum + percent }
            return sum
        }
        guard totalPct > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .mitigation(_, _, duration) = effect { return duration }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(Int(totalPct * 100))% mitigation, \(maxTicks) ticks left.")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .mitigation(keyword, percent, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .mitigation(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(
            .mitigation(adjustedKeyword, adjustedPercent, adjustedDuration),
            to: target,
            sourceID: source.id,
            remainingTicks: adjustedDuration
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .mitigationApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: Int(adjustedPercent * 100),
            keyword: adjustedKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

public struct LeechHandler: BattleEffectHandler {
    public let kind: EffectKind = .leech

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let percent = stacks.reduce(0.0) { maxPercent, effect in
            if case let .leech(_, value, _) = effect.effect { return max(maxPercent, value) }
            return maxPercent
        }
        guard percent > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .leech(_, _, duration) = effect { return duration }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(Int(percent * 100))% leech, \(maxTicks) ticks left.")
    }

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .leech(keyword, percent, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .leech(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let wisdomTicks = source.primaryStats.wisdom / 20
        var effects = context.activeEffects(for: target)
        effects.removeAll { if case .leech = $0.effect { return true }; return false }
        context.setActiveEffects(effects, for: target)
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
