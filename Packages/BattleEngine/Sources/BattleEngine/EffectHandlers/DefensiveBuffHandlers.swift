import Foundation
import TrinketContent
import TrinketCore

/// Handler for Block pool gains.
struct DefensePoolBuffHandler: BattleEffectHandler {
    let pool: DefensePoolEngine.Pool
    var kind: EffectKind {
        pool.effectKind
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = DefensePoolEngine.points(in: stacks, pool: pool)
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "\(keyword.rawValue): \(total).")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard let gain = pool.decodeGain(adjusted) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let applied = DefensePoolEngine.add(
            gain.amount,
            pool: pool,
            to: target,
            keyword: gain.keyword,
            sourceActorID: source.id,
            in: &context
        )

        let event = context.nextEvent(
            kind: .effect,
            effectKind: pool.appliedEffectKind,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: applied,
            keyword: gain.keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
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
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .leech(_, _, duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(
            keyword: keyword,
            text: "\(keyword.rawValue): \(Int(percent * 100))% leech, \(BattleTiming.remainingDurationLabel(turns: maxTicks))."
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
        guard case .leech = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let adjusted = context.adjustedOutgoingEffect(effect, sourceID: source.id)
        guard case let .leech(adjustedKeyword, adjustedPercent, adjustedDuration) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .leech = $0 {
                return true
            }
            return false
        }
        context.appendEffect(
            .leech(adjustedKeyword, adjustedPercent, adjustedDuration),
            to: target,
            sourceID: source.id,
            remainingTurns: adjustedDuration
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
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case .nextHolyStrike = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .nextHolyStrike = $0 {
                return true
            }
            return false
        }
        context.appendEffect(
            .nextHolyStrike,
            to: target,
            sourceID: source.id,
            remainingTurns: 0
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

struct NextStrikeDoubleHandler: BattleEffectHandler {
    let kind: EffectKind = .nextStrikeDouble

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(keyword: keyword, text: "Next attack deals double damage.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case .nextStrikeDouble = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .nextStrikeDouble = $0 {
                return true
            }
            return false
        }
        context.appendEffect(
            .nextStrikeDouble,
            to: target,
            sourceID: source.id,
            remainingTurns: 0
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .nextStrikeDoubleApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: .physical
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct EvadeNextHitHandler: BattleEffectHandler {
    let kind: EffectKind = .evadeNextHit

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(keyword: keyword, text: "Dodge the next attack.")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case .evadeNextHit = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .evadeNextHit = $0 {
                return true
            }
            return false
        }
        context.appendEffect(
            .evadeNextHit,
            to: target,
            sourceID: source.id,
            remainingTurns: 0
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .evadeNextHitApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: .dodge
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
