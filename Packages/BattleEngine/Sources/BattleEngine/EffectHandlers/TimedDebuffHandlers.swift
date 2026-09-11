import TrinketContent
import TrinketCore

struct TimedDebuffHandler: BattleEffectHandler {
    let kind: EffectKind

    func apply(
        _ effect: Effect,
        ability _: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
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
        case .damageReductionPercent:
            let multiplier = stacks.reduce(1.0) { result, active in
                guard case let .damageReductionPercent(percent, _) = active.effect else { return result }
                return result * (1 - min(1, percent))
            }
            let percentInt = Int(((1 - multiplier) * 100).rounded())
            return EffectSummary(
                keyword: keyword,
                text: "Weakened: Outgoing damage reduced by \(percentInt)%\(durationSuffix).",
            )
        case .damageReductionFlat:
            let amount = stacks.reduce(0) { result, active in
                guard case let .damageReductionFlat(amount, _) = active.effect else { return result }
                return result + amount
            }
            return EffectSummary(
                keyword: keyword,
                text: "Dazzled: Outgoing damage reduced by \(amount)\(durationSuffix).",
            )
        case .healingReductionPercent:
            let percent = stacks.reduce(0.0) { result, active in
                guard case let .healingReductionPercent(percent, _) = active.effect else { return result }
                return max(result, min(1, percent))
            }
            let percentInt = Int((percent * 100).rounded())
            return EffectSummary(
                keyword: keyword,
                text: "Sapped: Health restoration reduced by \(percentInt)%\(durationSuffix).",
            )
        default:
            return nil
        }
    }
}
