import Foundation
import TrinketContent
import TrinketCore

/// Shared handler for Block granted from a spent resource (all current Mana, flat
/// or half Mana, or Gold). `convertManaToBlock` spends the Mana and runs spend-Mana
/// reactions; the other modes only read their resource.
struct ShieldFromResourceHandler: BattleEffectHandler {
    enum Mode: Sendable {
        case convertManaToBlock
        case shieldFromMana
        case shieldFromHalfMana
        case shieldFromGold

        var kind: EffectKind {
            switch self {
            case .convertManaToBlock: .convertManaToBlock
            case .shieldFromMana: .shieldFromMana
            case .shieldFromHalfMana: .shieldFromHalfMana
            case .shieldFromGold: .shieldFromGold
            }
        }

        var spendsMana: Bool {
            switch self {
            case .convertManaToBlock: true
            case .shieldFromMana, .shieldFromHalfMana, .shieldFromGold: false
            }
        }
    }

    let mode: Mode

    var kind: EffectKind {
        mode.kind
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard effect.kind == mode.kind else {
            return EffectApplyOutcome(events: [], didApply: false)
        }

        let block: Int
        switch mode {
        case .convertManaToBlock:
            let mana = context.mana(of: target)
            guard mana > 0 else {
                return EffectApplyOutcome(events: [], didApply: false)
            }
            _ = context.spendMana(mana, for: target)
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

        let applied = DefensePoolEngine.add(
            block,
            pool: .block,
            to: target,
            keyword: .block,
            sourceActorID: source.id,
            in: &context
        )
        var events: [ActionEvent] = []
        if mode.spendsMana {
            events = CombatReactionEngine.afterSpendMana(by: target, in: &context)
        }
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .shieldApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: applied,
            keyword: .block
        ))
        return EffectApplyOutcome(events: events, didApply: true)
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
        return EffectSummary(keyword: keyword, text: "Maximum Mana +\(total).")
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .maximumManaBonus(amount) = effect, amount > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.appendEffect(
            .maximumManaBonus(amount),
            to: target,
            sourceID: source.id,
            remainingTurns: 0
        )
        let restored = context.restoreMana(
            context.paced(amount, sourceActorID: source.id),
            to: target,
            sourceActorID: source.id
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .resourceGain,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: max(amount, restored),
            keyword: .mana
        )
        var events = [event]
        if restored > 0 {
            events.append(contentsOf: CombatReactionEngine.afterGainMana(by: target, in: &context))
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
        action _: ActionApplyContext,
        in context: inout BattleState
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
            effectKind: .controlApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: multiplied,
            keyword: keyword
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
            text: "\(damageKeyword.rawValue): \(potency)/turn, \(BattleTiming.remainingDurationLabel(turns: active.remainingTurns))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .recurringDamage(keyword, potency, turns) = effect, potency > 0, turns > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var events = DoTDamage.resolveTurnDamage(
            basePotency: potency,
            keyword: keyword,
            target: target,
            sourceActorID: source.id,
            in: &context
        ).events
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case let .recurringDamage(existingKeyword, _, _) = $0 {
                return existingKeyword == keyword
            }
            return false
        }
        context.appendEffect(
            .recurringDamage(keyword, potency, turns),
            to: target,
            sourceID: source.id,
            remainingTurns: turns
        )
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .controlApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: potency,
            keyword: keyword
        ))
        return EffectApplyOutcome(events: events, didApply: true)
    }

    func advanceTurn(
        _ active: ActiveEffect,
        on target: Combatant,
        in context: inout BattleState
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
            in: &context
        ).events
        var updated = active
        updated.remainingTurns -= 1
        return EffectTurnOutcome(
            events: events,
            updatedStack: updated,
            removeAfter: updated.remainingTurns <= 0
        )
    }
}

struct HolyDamageBonusFromBlockHandler: BattleEffectHandler {
    let kind: EffectKind = .holyDamageBonusFromBlock

    func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        guard !stacks.isEmpty else { return nil }
        let minTurns = TimedBuffSummary.minRemainingTurns(in: stacks) { effect in
            if case let .holyDamageBonusFromBlock(duration) = effect {
                return duration
            }
            return nil
        }
        return EffectSummary(
            keyword: keyword,
            text: "Consecrated: Holy damage equal to Block, \(BattleTiming.remainingDurationLabel(turns: minTurns))."
        )
    }

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        guard case let .holyDamageBonusFromBlock(durationTurns) = effect, durationTurns > 0 else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        ActiveEffectMutation.removeMatching(from: target, in: &context) {
            if case .holyDamageBonusFromBlock = $0 {
                return true
            }
            return false
        }
        context.appendEffect(
            .holyDamageBonusFromBlock(durationTurns),
            to: target,
            sourceID: source.id,
            remainingTurns: durationTurns
        )
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .damageKeywordOverrideApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: .holy
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct ReviveHandler: BattleEffectHandler {
    let kind: EffectKind = .revive

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleState
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
            keyword: .health
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
