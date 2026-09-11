import Foundation
import TrinketContent
import TrinketCore

struct CleansePurgeHandler: BattleEffectHandler {
    enum Mode {
        case cleanse
        case cleanseRandom
        case purge
        case purgeRandom
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
        var currentEffects = context.roster.activeEffects(for: target)
        switch mode {
        case .cleanse:
            return applyCleanse(effect, ability: ability, source: source, target: target, in: &context)
        case .cleanseRandom:
            return applyCleanseRandom(ability: ability, source: source, target: target, in: &context)
        case .purge:
            return applyPurge(effect, ability: ability, source: source, target: target, currentEffects: &currentEffects, in: &context)
        case .purgeRandom:
            return applyPurgeRandom(ability: ability, source: source, target: target, currentEffects: &currentEffects, in: &context)
        }
    }

    private func applyCleanse(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        let targetKeyword: Keyword?
        let healPerDebuff: Int
        switch effect {
        case let .cleanse(keyword):
            targetKeyword = keyword
            healPerDebuff = 0
        case let .cleanseHealPerDebuff(healPer):
            targetKeyword = nil
            healPerDebuff = healPer
        default:
            return EffectApplyOutcome(events: [], didApply: false)
        }
        return CleanseOperation.resolve(
            .all(targetKeyword), source: source, target: target, abilityName: ability.name,
            healPerDebuff: healPerDebuff, origin: .direct, in: &context,
        ).application
    }

    private func applyCleanseRandom(
        ability: Ability,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        CleanseOperation.resolve(.random, source: source, target: target, abilityName: ability.name, origin: .direct, in: &context)
            .application
    }

    private func applyPurge(
        _ effect: Effect,
        ability: Ability,
        source: Combatant,
        target: Combatant,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard case let .purge(targetKeyword) = effect else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        let removed = EffectRemoval.removeBuffs(
            from: &currentEffects, keyword: targetKeyword,
            preservingBlock: context.modifiers(for: target.id).triggers.sealedSarcophagus,
        )
        guard !removed.isEmpty else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.roster.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: targetKeyword ?? .purge,
            origin: .direct,
        )
        CombatTriggerEngine.protectPurgedEffects(removed, source: source, target: target, in: &context)
        var events = [event]
        events.append(contentsOf: CombatTriggerEngine.crownfallDamage(
            removedCount: removed.count,
            source: source,
            target: target,
            in: &context,
        ))
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func applyPurgeRandom(
        ability: Ability,
        source: Combatant,
        target: Combatant,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        let preservingBlock = context.modifiers(for: target.id).triggers.sealedSarcophagus
        guard let removed = EffectRemoval.removeRandomBuff(
            from: &currentEffects, preservingBlock: preservingBlock, using: &context.rng,
        ) else {
            return EffectApplyOutcome(events: [], didApply: false)
        }
        context.roster.setActiveEffects(currentEffects, for: target)
        let event = context.nextEvent(
            kind: .effect,
            effectKind: .purgeApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: removed.keyword,
            origin: .direct,
        )
        CombatTriggerEngine.protectPurgedEffects([removed], source: source, target: target, in: &context)
        var events = [event]
        events.append(contentsOf: CombatTriggerEngine.crownfallDamage(
            removedCount: 1,
            source: source,
            target: target,
            in: &context,
        ))
        return EffectApplyOutcome(events: events, didApply: true)
    }
}
