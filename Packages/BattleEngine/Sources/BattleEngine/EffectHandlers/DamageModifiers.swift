import Foundation
import TrinketContent
import TrinketCore

struct HalveShieldHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .halveShield(keyword) = effect else { return EffectApplyOutcome(didApply: false) }
        guard DefensePoolEngine.halveBlock(on: target, in: &context) else {
            return EffectApplyOutcome(didApply: false)
        }
        context.nextEvent(
            kind: .effect(.shieldHalved),
            source: .init(source),
            abilityID: ability.id, abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: keyword,
            origin: .direct,
        )
        return EffectApplyOutcome(didApply: true)
    }
}

struct ControlMeterHandler: BattleEffectHandler {
    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let meterStacks = stacks.filter { activeEffect in
            guard case let .controlMeter(meterKeyword, _, _) = activeEffect.effect else { return false }
            return meterKeyword == keyword
        }
        guard let meter = meterStacks.first else { return nil }

        if meter.effect.isActionSkipPending {
            let alias = keyword.statusAlias ?? keyword.rawValue
            if meter.isAwaitingActionSkip {
                return EffectSummary(keyword: keyword, text: "\(alias): Next action is prevented")
            }
            return EffectSummary(keyword: keyword, text: "\(alias): Recovering from \(keyword.rawValue)")
        }
        guard let values = meter.effect.controlMeterValues else { return nil }
        let alias = keyword.statusAlias ?? keyword.rawValue
        let progress = Double(max(0, values.amount)) * 100 / Double(max(1, values.threshold))
        let percent = min(99, CombatRounding.rounded(progress.rounded(.down)))
        return EffectSummary(
            keyword: keyword,
            text: "\(percent)% \(alias)\nAt 100%, the next action is prevented",
        )
    }

    func advanceTurn(
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

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> EffectApplyOutcome {
        guard case let .controlMeter(keyword, amount, _) = effect else {
            return EffectApplyOutcome(didApply: false)
        }
        guard amount > 0 else {
            return EffectApplyOutcome(didApply: false)
        }
        let firstEventID = context.nextEventID
        let effectsBefore = context.roster.activeEffects(for: target)
        await ControlMeterEngine.applyMeterCharge(amount, keyword: keyword, to: target, sourceActorID: source.id, in: &context)
        _ = ability
        let didApply = context.nextEventID > firstEventID || context.roster.activeEffects(for: target) != effectsBefore
        return EffectApplyOutcome(didApply: didApply)
    }
}

struct MultiplyControlMeterHandler: BattleEffectHandler {
    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) async -> EffectApplyOutcome {
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
