import Foundation
import TrinketContent
import TrinketCore

struct ShieldFromResourceHandler: BattleEffectHandler {
    enum Mode {
        case convertManaToBlock
        case shieldFromMana
        case shieldFromHalfMana
        case shieldFromGold

        var spendsMana: Bool {
            switch self {
            case .convertManaToBlock: true
            case .shieldFromMana, .shieldFromHalfMana, .shieldFromGold: false
            }
        }
    }

    let mode: Mode
    let kind: EffectKind

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard effect.kind == kind else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let block: Int
        var spentAmount = 0
        switch mode {
        case .convertManaToBlock:
            let mana = context.mana(of: target)
            guard mana > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            _ = context.spendMana(mana, for: target)
            spentAmount = mana
            block = mana
        case .shieldFromMana:
            let mana = context.mana(of: target)
            guard mana > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = mana
        case .shieldFromHalfMana:
            let half = context.mana(of: target) / 2
            guard half > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = half
        case .shieldFromGold:
            guard case let .shieldFromGold(goldPerBlock) = effect, goldPerBlock > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            let fromGold = context.gold / goldPerBlock
            guard fromGold > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            block = fromGold
        }

        let applied = context.applyBlock(
            block,
            to: target,
            source: source,
            abilityName: ability.name,
        )
        var events: [ActionEvent] = []
        if mode.spendsMana {
            events = CombatTriggerEngine.afterSpendMana(
                by: target,
                amountSpent: spentAmount,
                in: &context,
            )
        }
        events.append(contentsOf: applied)
        return EffectApplyOutcome(events: events, didApply: !applied.isEmpty)
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
        )
        var events = [event]
        if restored > 0 {
            events.append(contentsOf: CombatTriggerEngine.afterGainMana(by: target, in: &context))
        }
        return EffectApplyOutcome(events: events, didApply: true)
    }
}

struct MultiplyDoTHandler: BattleEffectHandler {
    let kind: EffectKind = .multiplyDoT

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .multiplyDoT(keyword, factor) = effect, factor > 1 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var effects = context.roster.activeEffects(for: target)
        guard let index = effects.firstIndex(where: {
            $0.effect.keyword == keyword && ($0.effect.isDecayingDoT || $0.effect.isBleed)
        }) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let potency = effects[index].effect.potency ?? 0
        let multiplied = potency * factor
        switch keyword {
        case .burn:
            effects[index].effect = .burn(multiplied)
        case .poison:
            effects[index].effect = .poison(multiplied)
        case .bleed:
            effects[index].effect = .bleed(multiplied)
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.roster.setActiveEffects(effects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .dotAmplified,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: multiplied,
            keyword: keyword,
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct RecurringDamageHandler: BattleEffectHandler {
    let kind: EffectKind = .recurringDamage

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .recurringDamage(damageKeyword, potency, _) = active.effect
        else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "\(damageKeyword.rawValue): Deals \(potency) \(damageKeyword.rawValue) damage each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns)).",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .recurringDamage(keyword, potency, turns) = effect, potency > 0, turns > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var events = DoTDamage.resolveTurnDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: source.id,
            in: &context,
        ).events
        events.append(ActiveEffectMutation.replaceAndEmit(
            .recurringDamage(keyword, potency, turns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: {
                if case let .recurringDamage(existingKeyword, _, _) = $0 {
                    return existingKeyword == keyword
                }
                return false
            },
            event: (.recurringDamageApplied, potency, keyword),
        ))
        return EffectApplyOutcome(events: events, didApply: true)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> EffectTurnOutcome {
        guard case let .recurringDamage(keyword, potency, _) = active.effect,
              active.remainingTurns > 0
        else {
            return EffectTurnOutcome()
        }
        let sourceID = active.sourceActorID ?? target.id
        let events = DoTDamage.resolveTurnDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: sourceID,
            in: &context,
        ).events
        var updated = active
        updated.remainingTurns -= 1
        return EffectTurnOutcome(
            events: events,
            updatedStack: updated,
            removeAfter: updated.remainingTurns <= 0,
        )
    }
}

struct AvatarHandler: BattleEffectHandler {
    let kind: EffectKind = .avatar

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard let active = stacks.first,
              case let .avatar(holyDamage, blockPerTurn, _) = active.effect
        else { return nil }
        return EffectSummary(
            keyword: keyword,
            text: "Avatar: Deals \(holyDamage) Holy damage and gains \(blockPerTurn) Block each turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns)).",
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .avatar(holyDamage, blockPerTurn, turns) = effect,
              holyDamage > 0, blockPerTurn > 0, turns > 0
        else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var events = pulse(
            holyDamage: holyDamage,
            blockPerTurn: blockPerTurn,
            from: target,
            in: &context,
        )
        events.append(ActiveEffectMutation.replaceAndEmit(
            .avatar(holyDamage: holyDamage, blockPerTurn: blockPerTurn, turns: turns),
            to: target,
            source: source,
            ability: ability,
            in: &context,
            replacing: { $0.kind == .avatar },
            event: (.avatarApplied, holyDamage, .holy),
        ))
        return EffectApplyOutcome(events: events, didApply: true)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState,
    ) -> EffectTurnOutcome {
        guard case let .avatar(holyDamage, blockPerTurn, _) = active.effect,
              active.remainingTurns > 0
        else {
            return EffectTurnOutcome()
        }
        let events = pulse(
            holyDamage: holyDamage,
            blockPerTurn: blockPerTurn,
            from: target,
            in: &context,
        )
        var updated = active
        updated.remainingTurns -= 1
        return EffectTurnOutcome(
            events: events,
            updatedStack: updated,
            removeAfter: updated.remainingTurns <= 0,
        )
    }

    private func pulse(
        holyDamage: Int,
        blockPerTurn: Int,
        from caster: Combatant,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        let opponent: Combatant = caster.role == .enemy ? context.hero : context.enemy
        var events = DoTDamage.resolveTurnDamage(
            basePotency: holyDamage,
            keyword: .holy,
            target: opponent,
            sourceActorID: caster.id,
            in: &context,
        ).events
        let applied = DefensePoolEngine.add(
            blockPerTurn,
            to: caster,
            keyword: .block,
            sourceActorID: caster.id,
            in: &context,
        )
        if applied > 0 {
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .shieldApplied,
                actorName: caster.name,
                abilityName: "Avatar",
                target: caster,
                amount: applied,
                keyword: .block,
            ))
        }
        return events
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
