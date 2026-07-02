import Foundation

struct InstantHealHandler: BattleEffectHandler {
    let kind: EffectKind = .instantHeal

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .instantHeal(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        context.applyHeal(amount, to: target, sourceActorID: source.id)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .instantHeal,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct ResourceGainHandler: BattleEffectHandler {
    let kind: EffectKind = .resourceGain

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .resourceGain(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        context.addGold(amount, sourceActorID: source.id)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: amount,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
