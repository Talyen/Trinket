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

struct MaximumManaBonusHandler: BattleEffectHandler {
    let kind: EffectKind = .maximumManaBonus

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        let total = stacks.reduce(0) { sum, active in
            if case let .maximumManaBonus(amount) = active.effect {
                return sum + amount
            }
            return sum
        }
        guard total > 0 else { return nil }
        return EffectSummary(keyword: keyword, text: "Maximum Mana: Increases Maximum Mana by +\(total).")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .maximumManaBonus(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(
            .maximumManaBonus(amount),
            to: target,
            sourceID: source.id,
            remainingTurns: 0,
        )
        let restored = context.restoreMana(
            context.paced(amount, sourceActorID: source.id),
            to: target,
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: max(amount, restored),
            keyword: .mana,
            origin: .direct,
        )
        var events = [event]
        if restored > 0 {
            events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: target, in: &context))
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

struct ReviveHandler: BattleEffectHandler {
    let kind: EffectKind = .revive

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .revive(health) = effect, health > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        guard context.roster.health(for: target) <= 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var revivedHealth = 0
        context.roster.mutateRuntime(for: target) { runtime in
            runtime.currentHealth = min(health, runtime.maxHealth)
            revivedHealth = runtime.currentHealth
        }
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .instantHeal,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: revivedHealth,
            keyword: .health,
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
