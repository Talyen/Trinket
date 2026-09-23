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
                amount: restored,
                keyword: keyword,
                origin: .direct,
            )
            var events = [event]
            if restored > 0 {
                events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: target, in: &context))
            }
            events.append(contentsOf: CombatTriggerEngine.consumeManaOverflowTalents(
                for: target, restoredMana: restored > 0, in: &context,
            ))
            return EffectApplyOutcome(events: events, didApply: true)
        case .gold:
            return EffectApplyOutcome(
                events: context.grantGoldEvent(
                    amount, to: source, abilityName: ability.name,
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
        events.append(contentsOf: CombatTriggerEngine.consumeManaOverflowTalents(
            for: target, restoredMana: restored > 0, in: &context,
        ))
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
        let events = context.reviveEmitting(target, health: health, source: source, abilityName: ability.name)
        return EffectApplyOutcome(events: events, didApply: !events.isEmpty)
    }
}

package extension BattleState {
    mutating func reviveEmitting(
        _ target: Combatant,
        health: Int,
        source: Combatant,
        abilityName: String,
    ) -> [ActionEvent] {
        guard health > 0, roster.health(for: target) <= 0 else { return [] }
        var revivedHealth = 0
        roster.mutateRuntime(for: target) { runtime in
            runtime.currentHealth = min(health, runtime.maxHealth)
            revivedHealth = runtime.currentHealth
        }
        return [nextEvent(
            kind: .effect,
            effectKind: .instantHeal,
            actorName: source.name,
            abilityName: abilityName,
            target: target,
            amount: revivedHealth,
            keyword: .health,
        )]
    }
}
