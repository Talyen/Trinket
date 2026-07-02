import Foundation

struct HalveMitigationHandler: BattleEffectHandler {
    let kind: EffectKind = .halveMitigation

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .halveMitigation(keyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
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
        context.setActiveEffects(currentEffects, for: target)
        guard didHalve else { return EffectApplyOutcome(events: [], didApply: true) }
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

struct PreventionBuildupHandler: BattleEffectHandler {
    let kind: EffectKind = .preventionBuildup

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let amount = stacks.compactMap { eff -> Int? in
            if case let .preventionBuildup(_, amt, _) = eff.effect { return amt }
            return nil
        }.reduce(0, +)
        let threshold = stacks.compactMap { eff -> Int? in
            if case let .preventionBuildup(_, _, th) = eff.effect { return th }
            return nil
        }.max() ?? 1
        return EffectSummary(
            keyword: keyword,
            text: "\(keyword.rawValue) Build-up: \(amount)/\(threshold)"
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .preventionBuildup(keyword, amount, _) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let events = CombatPipeline.applyPreventionBuildup(
            amount,
            keyword: keyword,
            to: target,
            sourceActorID: source.id,
            host: &context
        )
        _ = ability
        return EffectApplyOutcome(events: events, didApply: amount > 0 && context.health(of: target) > 0)
    }
}
