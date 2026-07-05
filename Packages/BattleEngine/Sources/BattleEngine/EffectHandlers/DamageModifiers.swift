import Foundation
import TrinketCore
import TrinketContent

public struct HalveMitigationHandler: BattleEffectHandler {
    public let kind: EffectKind = .halveMitigation

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .halveMitigation(keyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.roster.activeEffects(for: target)
        var didHalve = false
        for index in currentEffects.indices {
            if case let .mitigation(mitigationKeyword, percent, duration) = currentEffects[index].effect,
               mitigationKeyword == keyword {
                currentEffects[index].effect = .mitigation(
                    mitigationKeyword,
                    percent / 2,
                    duration
                )
                didHalve = true
            }
        }
        context.roster.setActiveEffects(currentEffects, for: target)
        guard didHalve else { return EffectApplyOutcome(events: [], didApply: false) }
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .mitigationHalved,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

public struct ControlMeterHandler: BattleEffectHandler {
    public let kind: EffectKind = .controlMeter

    public func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
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

    public func apply(
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
        let events = ControlMeterEngine.applyMeterCharge(
            amount,
            keyword: keyword,
            to: target,
            sourceActorID: source.id,
            in: &context
        )
        _ = ability
        return EffectApplyOutcome(events: events, didApply: amount > 0 && context.roster.health(for: target) > 0)
    }
}
