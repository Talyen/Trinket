import Foundation

struct PreventionHandler: BattleEffectHandler {
    let kind: EffectKind = .prevention

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let maxActions = stacks.compactMap { eff -> Int? in
            if case .prevention = eff.effect { return eff.remainingTicks }
            return nil
        }.min() ?? 0
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(maxActions) actions prevented.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .prevention(keyword, duration) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        guard context.health(of: target) > 0 else { return EffectApplyOutcome(events: [], didApply: false) }
        context.appendEffect(
            .prevention(keyword, duration),
            to: target,
            sourceID: source.id,
            remainingTicks: duration
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .preventionApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct ShieldHandler: BattleEffectHandler {
    let kind: EffectKind = .shield

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
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

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
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

struct MitigationHandler: BattleEffectHandler {
    let kind: EffectKind = .mitigation

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
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

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
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

struct DodgeHandler: BattleEffectHandler {
    let kind: EffectKind = .dodge

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .dodge(_, duration) = effect { return duration }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(maxTicks) ticks.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .dodge(keyword, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        context.appendEffect(effect, to: target, sourceID: source.id, remainingTicks: durationTicks)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .dodgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct LeechHandler: BattleEffectHandler {
    let kind: EffectKind = .leech

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let totalPct = stacks.reduce(0.0) { sum, effect in
            if case let .leech(_, percent, _) = effect.effect { return sum + percent }
            return sum
        }
        guard totalPct > 0 else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTicks(in: stacks) { effect in
            if case let .leech(_, _, duration) = effect { return duration }
            return nil
        }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(Int(totalPct * 100))% leech, \(maxTicks) ticks left.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .leech(keyword, percent, durationTicks) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .leech(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let wisdomTicks = source.primaryStats.wisdom / 20
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
