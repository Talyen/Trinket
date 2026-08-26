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
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        context.appendEffect(effect, to: target, sourceID: source.id, remainingTurns: effect.durationTurns)
        return EffectApplyOutcome(events: [], didApply: true)
    }

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first else { return nil }
        let maxTicks = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            effect.durationTurns > 0 ? effect.durationTurns : nil
        }
        let durationSuffix = maxTicks > 0 ? ", \(BattleTiming.remainingDurationLabel(turns: maxTicks))" : ""
        switch active.effect {
        case let .damageReductionPercent(percent, _):
            let percentInt = Int((percent * 100).rounded())
            return EffectSummary(
                keyword: keyword,
                text: "Weakened: outgoing damage reduced by \(percentInt)%\(durationSuffix)."
            )
        case let .damageReductionFlat(amount, _):
            return EffectSummary(
                keyword: keyword,
                text: "Dazzled: outgoing damage reduced by \(amount)\(durationSuffix)."
            )
        case let .strengthReduction(amount, _):
            return EffectSummary(
                keyword: keyword,
                text: "Weakened Soul: Strength reduced by \(amount)\(durationSuffix)."
            )
        default:
            return nil
        }
    }
}
