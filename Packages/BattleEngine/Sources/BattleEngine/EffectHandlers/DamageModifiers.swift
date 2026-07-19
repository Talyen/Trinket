import Foundation
import TrinketContent
import TrinketCore

struct HalveShieldHandler: BattleEffectHandler {
    let kind: EffectKind = .halveShield

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .halveShield(keyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        guard DefensePoolEngine.halveBlock(on: target, in: &context) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .shieldHalved,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct ControlMeterHandler: BattleEffectHandler {
    let kind: EffectKind = .controlMeter

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let meterStacks = stacks.filter { activeEffect in
            guard case let .controlMeter(meterKeyword, _, _) = activeEffect.effect else { return false }
            return meterKeyword == keyword
        }
        guard let meter = meterStacks.first else { return nil }

        if meter.effect.isActionSkipPending {
            let alias = keyword.statusAlias ?? keyword.rawValue
            return EffectSummary(keyword: keyword, text: "\(alias): action prevented.")
        }
        guard let values = meter.effect.controlMeterValues else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "\(keyword.rawValue) Build-up: \(values.amount)/\(values.threshold)"
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .controlMeter(keyword, amount, _) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        guard amount > 0, context.roster.health(for: target) > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let effectsBefore = context.roster.activeEffects(for: target)
        let events = ControlMeterEngine.applyMeterCharge(
            amount,
            keyword: keyword,
            to: target,
            sourceActorID: source.id,
            in: &context
        )
        _ = ability
        let didApply = !events.isEmpty || context.roster.activeEffects(for: target) != effectsBefore
        return EffectApplyOutcome(events: events, didApply: didApply)
    }
}
