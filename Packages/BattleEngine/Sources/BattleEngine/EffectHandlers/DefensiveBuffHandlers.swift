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
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .shield(_, amount) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let gain = context.applyBlockGain(
            amount,
            to: target,
            source: source,
            abilityName: ability.name
        )
        return EffectApplyOutcome(events: gain.applied > 0 ? gain.events : [], didApply: gain.applied > 0)
    }
}

/// Shared handler for one-shot "next …" flag effects: any existing stack of the
/// same kind is dropped, the flag is reapplied with zero remaining turns, and a
/// single "applied" event is emitted.
struct FlagEffectHandler: BattleEffectHandler {
    let flag: Effect
    let appliedEffectKind: ActionEvent.EffectOutcome
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
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard effect == flag else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = ActiveEffectMutation.replaceAndEmit(
            flag,
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0 == flag },
            event: (appliedEffectKind, amount, keyword)
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
