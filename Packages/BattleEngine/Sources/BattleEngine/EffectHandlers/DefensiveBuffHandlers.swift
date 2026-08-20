import Foundation
import TrinketContent
import TrinketCore

/// Handler for Block pool gains.
struct BlockBuffHandler: BattleEffectHandler {
    let kind: EffectKind = .shield

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = DefensePoolEngine.blockPoints(in: stacks)
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
        guard case let .shield(keyword, amount) = adjusted else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let applied = DefensePoolEngine.add(
            amount,
            to: target,
            keyword: keyword,
            sourceActorID: source.id,
            in: &context
        )

        let event = context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: applied,
            keyword: keyword
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
        ActiveEffectMutation.removeMatching(from: target, in: &context) { active in
            if case .leech = active {
                true
            } else {
                false
            }
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

/// Shared handler for one-shot "next …" flag effects: any existing stack of the
/// same kind is dropped, the flag is reapplied with zero remaining turns, and a
/// single "applied" event is emitted.
struct FlagEffectHandler: BattleEffectHandler {
    let flag: Effect
    let appliedEffectKind: ActionEvent.EffectKind
    let amount: Int
    let keyword: Keyword
    let summaryText: String

    var kind: EffectKind {
        flag.kind
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        return EffectSummary(keyword: keyword, text: summaryText)
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard effect == flag else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) { $0 == flag }
        context.appendEffect(flag, to: target, sourceID: source.id, remainingTurns: 0)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: appliedEffectKind,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
