import Foundation
import TrinketCore
import TrinketContent

public struct InstantHealHandler: BattleEffectHandler {
    public let kind: EffectKind = .instantHeal

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .instantHeal(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: amount,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(
                    actorName: source.name,
                    abilityName: ability.name,
                    keyword: keyword,
                    displayAmount: amount
                )
            ),
            in: &context
        )
        return EffectApplyOutcome(events: outcome.events, didApply: true)
    }
}

public struct ResourceGainHandler: BattleEffectHandler {
    public let kind: EffectKind = .resourceGain

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .resourceGain(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let loggedAmount: Int
        switch keyword {
        case .mana:
            context.restoreMana(amount, to: target, sourceActorID: source.id)
            loggedAmount = amount
        case .gold:
            let bonus = context.modifiers(for: source.id).goldGainedBonus
            context.addGold(amount, sourceActorID: source.id)
            loggedAmount = amount + bonus
        default:
            context.addGold(amount, sourceActorID: source.id)
            loggedAmount = amount
        }
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: loggedAmount,
            keyword: keyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
