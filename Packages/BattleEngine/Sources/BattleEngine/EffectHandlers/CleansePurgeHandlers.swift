import Foundation
import TrinketContent
import TrinketCore

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
        guard case let .cleanse(targetKeyword) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var currentEffects = context.roster.activeEffects(for: target)
        let removed = EffectRemoval.removeDebuffs(from: &currentEffects, keyword: targetKeyword)
        guard removed else { return EffectApplyOutcome(events: [], didApply: false) }
        context.roster.setActiveEffects(currentEffects, for: target)
        return CleansePurgeSupport.applyCleanse(
            removedKeyword: targetKeyword ?? .health,
            ability: ability,
            source: source,
            target: target,
            in: &context
        )
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
        var currentEffects = context.roster.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomDebuff(from: &currentEffects, using: &context.rng)
        guard let removedKeyword else { return EffectApplyOutcome(events: [], didApply: false) }
        context.roster.setActiveEffects(currentEffects, for: target)
        return CleansePurgeSupport.applyCleanse(
            removedKeyword: removedKeyword,
            ability: ability,
            source: source,
            target: target,
            in: &context
        )
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
        guard case let .purge(targetKeyword) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        var currentEffects = context.roster.activeEffects(for: target)
        let removed = EffectRemoval.removeBuffs(from: &currentEffects, keyword: targetKeyword)
        guard removed else { return EffectApplyOutcome(events: [], didApply: false) }
        context.roster.setActiveEffects(currentEffects, for: target)
        return CleansePurgeSupport.applyPurge(
            removedKeyword: targetKeyword ?? .purge,
            ability: ability,
            source: source,
            target: target,
            in: &context
        )
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
        var currentEffects = context.roster.activeEffects(for: target)
        let removedKeyword = EffectRemoval.removeRandomBuff(from: &currentEffects, using: &context.rng)
        guard let removedKeyword else { return EffectApplyOutcome(events: [], didApply: false) }
        context.roster.setActiveEffects(currentEffects, for: target)
        return CleansePurgeSupport.applyPurge(
            removedKeyword: removedKeyword,
            ability: ability,
            source: source,
            target: target,
            in: &context
        )
    }
}

private enum CleansePurgeSupport {
    static func applyCleanse(
        removedKeyword: Keyword,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: removedKeyword
        )
        var events = [event]
        events.append(contentsOf: TraitReactionEngine.healAfterCleanse(
            source: source,
            target: target,
            in: &context
        ).events)
        return EffectApplyOutcome(events: events, didApply: true)
    }

    static func applyPurge(
        removedKeyword: Keyword,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleEngineContext
    ) -> EffectApplyOutcome {
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
