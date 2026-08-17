import TrinketContent
import TrinketCore

/// Handles the combatant-talent timed debuffs (Blinding Carapace, Dazzle, Weaken Soul).
/// They advance each turn via the default `advanceTurn` and are applied either
/// through a card effect or directly via `BattleState.appendEffect`.
struct TimedDebuffHandler: BattleEffectHandler {
    let kind: EffectKind

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        context.appendEffect(effect, to: target, sourceID: source.id, remainingTurns: effect.durationTurns)
        return EffectApplyOutcome(events: [], didApply: true)
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first else { return nil }
        switch active.effect {
        case let .damageReductionPercent(percent, _):
            return EffectSummary(keyword: keyword, text: "Damage -\(Int((percent * 100).rounded()))%")
        case let .damageReductionFlat(amount, _):
            return EffectSummary(keyword: keyword, text: "Damage -\(amount)")
        case let .strengthReduction(amount, _):
            return EffectSummary(keyword: keyword, text: "Strength -\(amount)")
        default:
            return nil
        }
    }
}
