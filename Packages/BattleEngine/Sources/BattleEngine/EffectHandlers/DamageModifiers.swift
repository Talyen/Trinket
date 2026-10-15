import Foundation
import TrinketContent
import TrinketCore

extension EffectHandlers {
    static func summarizeControlMeter(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let meterStacks = stacks.filter { activeEffect in
            guard case let .controlMeter(meterKeyword, _, _) = activeEffect.effect else { return false }
            return meterKeyword == keyword
        }
        guard let meter = meterStacks.first else { return nil }

        if meter.effect.isActionSkipPending {
            let alias = ContentCopy.resource(keyword.statusAlias ?? keyword.rawValue)
            if meter.isAwaitingActionSkip {
                return EffectSummary(keyword: keyword, resource: L10n.summary_damagemodifiers_a54b991fe1d3(alias))
            }
            return EffectSummary(keyword: keyword, resource: L10n.summary_damagemodifiers_86246b48dd06(alias, keyword.nameResource))
        }
        guard let values = meter.effect.controlMeterValues else { return nil }
        let alias = ContentCopy.resource(keyword.statusAlias ?? keyword.rawValue)
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
        guard case let .multiplyControlMeter(keyword, factor) = effect,
              keyword == .freeze,
              factor > 1
        else {
            return EffectApplyOutcome(didApply: false)
        }

        let firstEventID = context.nextEventID
        let effectsBefore = context.roster.activeEffects(for: target)
        await ControlMeterEngine.multiplyBuildup(
            factor,
            keyword: keyword,
            to: target,
            sourceActorID: source.id,
            abilityID: ability.id, abilityName: ability.name,
            in: &context,
        )
        let didApply = context.nextEventID > firstEventID || context.roster.activeEffects(for: target) != effectsBefore
        return EffectApplyOutcome(didApply: didApply)
    }
}
