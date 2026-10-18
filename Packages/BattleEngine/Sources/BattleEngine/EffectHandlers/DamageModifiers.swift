import Foundation
import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func summarizeControlMeter(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let meter = stacks.first(where: { activeEffect in
            guard case let .controlMeter(meterKeyword, _, _) = activeEffect.effect else { return false }
            return meterKeyword == keyword
        }) else { return nil }

        if meter.effect.isActionSkipPending {
            let alias = ContentCopy.resource(keyword.statusName)
            if meter.isAwaitingActionSkip {
                return EffectSummary(keyword: keyword, resource: L10n.summary_damagemodifiers_a54b991fe1d3(alias))
            }
            return EffectSummary(keyword: keyword, resource: L10n.summary_damagemodifiers_86246b48dd06(alias, keyword.nameResource))
        }
        guard let values = meter.effect.controlMeterValues else { return nil }
        let alias = ContentCopy.resource(keyword.statusName)
        let progress = Double(max(0, values.amount)) * 100 / Double(max(1, values.threshold))
        let percent = min(99, CombatRounding.rounded(progress.rounded(.down)))
        return EffectSummary(
            keyword: keyword,
            resource: L10n.summary_damagemodifiers_6dc3859fb861(percent, alias),
        )
    }

    static func advanceControlMeter(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) {
        guard active.remainingTurns > 0 else { return }
        var updated = active
        updated.remainingTurns -= 1
        if updated.remainingTurns == 0, let restored = UniqueCombatEngine.recoveredStun(updated, in: &context) {
            ActiveEffectMutation.finishTurn(active, replacement: restored, on: target, in: &context)
            return
        }
        ActiveEffectMutation.finishTurn(
            active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context,
        )
    }
}

extension EffectApplication {
    func applyMultiplyControlMeter(in context: inout BattleState) async -> EffectApplyOutcome {
        guard case let .multiplyControlMeter(keyword, factor) = effect else {
            return EffectApplyOutcome(didApply: false)
        }

        let didApply = await ControlMeterEngine.multiplyBuildup(
            factor,
            keyword: keyword,
            to: target,
            sourceActorID: source.id,
            abilityID: ability.id, abilityName: ability.name,
            in: &context,
        )
        return EffectApplyOutcome(didApply: didApply)
    }
}
