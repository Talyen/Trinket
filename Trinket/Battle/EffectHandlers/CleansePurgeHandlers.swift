import Foundation

struct CleanseHandler: BattleEffectHandler {
    let kind: EffectKind = .cleanse

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .cleanse(targetKeyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
        EffectRemoval.removeDebuffs(from: &currentEffects, keyword: targetKeyword)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = targetKeyword ?? .health
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct CleanseRandomHandler: BattleEffectHandler {
    let kind: EffectKind = .cleanseRandom

    func apply(
        _: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        var currentEffects = context.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomDebuff(from: &currentEffects, using: &context.rng)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = removedKeyword ?? .health
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct PurgeHandler: BattleEffectHandler {
    let kind: EffectKind = .purge

    func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        guard case let .purge(targetKeyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
        EffectRemoval.removeBuffs(from: &currentEffects, keyword: targetKeyword)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = targetKeyword ?? .purge
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

struct PurgeRandomHandler: BattleEffectHandler {
    let kind: EffectKind = .purgeRandom

    func apply(
        _: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleMutationContext
    ) -> EffectApplyOutcome {
        var currentEffects = context.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomBuff(from: &currentEffects, using: &context.rng)
        context.setActiveEffects(currentEffects, for: target)
        let eventKeyword = removedKeyword ?? .purge
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: eventKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
