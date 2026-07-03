import Foundation
import TrinketCore
import TrinketContent

public struct CleanseHandler: BattleEffectHandler {
    public let kind: EffectKind = .cleanse

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .cleanse(targetKeyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
        let removed = EffectRemoval.removeDebuffs(from: &currentEffects, keyword: targetKeyword)
        guard removed else { return EffectApplyOutcome(events: [], didApply: false) }
        context.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: targetKeyword ?? .health
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

public struct CleanseRandomHandler: BattleEffectHandler {
    public let kind: EffectKind = .cleanseRandom

    public func apply(
        _: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        var currentEffects = context.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomDebuff(from: &currentEffects, using: &context.rng)
        guard let removedKeyword else { return EffectApplyOutcome(events: [], didApply: false) }
        context.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: removedKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

public struct PurgeHandler: BattleEffectHandler {
    public let kind: EffectKind = .purge

    public func apply(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        guard case let .purge(targetKeyword) = effect else { return EffectApplyOutcome(events: [], didApply: false) }
        var currentEffects = context.activeEffects(for: target)
        let removed = EffectRemoval.removeBuffs(from: &currentEffects, keyword: targetKeyword)
        guard removed else { return EffectApplyOutcome(events: [], didApply: false) }
        context.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: targetKeyword ?? .purge
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}

public struct PurgeRandomHandler: BattleEffectHandler {
    public let kind: EffectKind = .purgeRandom

    public func apply(
        _: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        action _: ActionApplyContext,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        var currentEffects = context.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomBuff(from: &currentEffects, using: &context.rng)
        guard let removedKeyword else { return EffectApplyOutcome(events: [], didApply: false) }
        context.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: removedKeyword
        )
        return EffectApplyOutcome(events: [event], didApply: true)
    }
}
