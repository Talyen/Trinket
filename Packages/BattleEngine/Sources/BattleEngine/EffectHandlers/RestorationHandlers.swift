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
        action _: ActionApplyContext,
        in context: inout BattleState
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
        guard outcome.healthRestored > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
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
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .resourceGain(keyword, amount) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        let loggedAmount: Int
        switch keyword {
        case .mana:
            let restored = context.restoreMana(amount, to: target, sourceActorID: source.id)
            loggedAmount = amount
            let event = context.nextEvent(
                kind: .effect,
                effectKind: .resourceGain,
                actorName: source.name,
                abilityName: ability.name,
                target: target,
                amount: loggedAmount,
                keyword: keyword
            )
            var events = [event]
            if restored > 0 {
                events.append(contentsOf: CombatReactionEngine.afterGainMana(by: target, in: &context))
            }
            return EffectApplyOutcome(events: events, didApply: true)
        case .gold:
            loggedAmount = context.goldGranted(for: amount, sourceActorID: source.id)
            context.addGold(amount, sourceActorID: source.id)
        default:
            return EffectApplyOutcome(events: [], didApply: false)
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
        var events = [event]
        if keyword == .gold {
            events.append(contentsOf: TraitReactionEngine.healSelfAfterGoldGain(source: source, in: &context).events)
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

struct DrawCardsHandler: BattleEffectHandler {
    let kind: EffectKind = .drawCards

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .drawCards(count) = effect, count > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let drawTarget = target
        guard let owner = context.roster.participant(for: drawTarget), owner.isPartyMember else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let drawn = BattleCardCombatEngine.drawCards(count: count, for: owner, context: &context)
        guard drawn > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cardsDrawn,
            actorName: source.name,
            abilityName: ability.name,
            target: drawTarget,
            amount: drawn,
            keyword: .physical
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
