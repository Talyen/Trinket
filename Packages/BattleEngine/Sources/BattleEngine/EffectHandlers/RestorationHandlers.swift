import Foundation
import TrinketContent
import TrinketCore

struct InstantHealHandler: BattleEffectHandler {
    let kind: EffectKind = .instantHeal

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .instantHeal(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var request = HealRequest(
            amount: amount, target: target, sourceActorID: source.id,
            origin: .restoration(keyword), logAs: .instantHeal(actorName: source.name, abilityName: ability.name, keyword: keyword),
        )
        request.isDirectCardHeal = context.hasHeroCard(for: source.id)
        let outcome = HealingEngine.resolveHeal(request, in: &context)
        guard outcome.healthRestored > 0 else {
            return EffectApplyOutcome(events: outcome.events, didApply: false)
        }
        return EffectApplyOutcome(events: outcome.events, didApply: true)
    }
}

struct ResourceGainHandler: BattleEffectHandler {
    let kind: EffectKind = .resourceGain

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .resourceGain(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        switch keyword {
        case .mana:
            let bonus = amount > 0 ? CombatTriggerEngine.heroCardManaBonus(source: source, target: target, in: &context) : 0
            let restored = context.restoreMana(
                context.paced(amount, sourceActorID: source.id) + bonus,
                to: target,
            )
            CombatTriggerEngine.afterHeroCardMana(source: source, restored: restored, in: &context)
            let event = context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: source.name,
                abilityName: ability.name,
                target: target,
                amount: restored,
                keyword: keyword,
                origin: .direct,
            )
            var events = [event]
            if restored > 0 {
                events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: target, in: &context))
            }
            return EffectApplyOutcome(events: events, didApply: true)
        case .gold:
            let bonus = CombatTriggerEngine.heroCardGoldBonus(source: source, amount: amount, in: &context)
            return EffectApplyOutcome(
                events: context.grantGoldEvent(
                    amount + bonus, to: source, abilityName: ability.name,
                    isTheft: ability.stealsGold, isDirectCardGain: true,
                ),
                didApply: true,
            )
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
    }
}
