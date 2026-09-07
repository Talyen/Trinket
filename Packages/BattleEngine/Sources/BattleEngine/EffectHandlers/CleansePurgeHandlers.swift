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
            return applyCleanse(effect, ability: ability, source: source, target: target, currentEffects: &currentEffects, in: &context)
        case .cleanseRandom:
            return applyCleanseRandom(ability: ability, source: source, target: target, currentEffects: &currentEffects, in: &context)
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
        currentEffects: inout [ActiveEffect],
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
        let removed = EffectRemoval.removeDebuffs(from: &currentEffects, keyword: targetKeyword)
        guard !removed.isEmpty else {
            var events = CombatTriggerEngine.afterHeroCleanse(source: source, target: target, removed: [], in: &context)
            let partyEvents = CombatTriggerEngine.cleanseOtherPartyMember(source: source, target: target, in: &context)
            events.append(contentsOf: partyEvents)
            return EffectApplyOutcome(events: events, didApply: !partyEvents.isEmpty)
        }
        context.roster.setActiveEffects(currentEffects, for: target)
        let healAmount = healPerDebuff > 0 ? healPerDebuff * removed.count : nil
        let events = CleanseEventBuilder.events(
            removed: removed,
            abilityName: ability.name,
            source: source,
            target: target,
            healAmount: healAmount,
            healTarget: target,
            in: &context,
        )
        return EffectApplyOutcome(events: events, didApply: true)
    }

    private func applyCleanseRandom(
        ability: Ability,
        source: Combatant,
        target: Combatant,
        currentEffects: inout [ActiveEffect],
        in context: inout BattleState,
    ) -> EffectApplyOutcome {
        guard let keyword = EffectRemoval.removeRandomDebuff(from: &currentEffects, using: &context.rng) else {
            var events = CombatTriggerEngine.afterHeroCleanse(source: source, target: target, removed: [], in: &context)
            let partyEvents = CombatTriggerEngine.cleanseOtherPartyMember(source: source, target: target, in: &context)
            events.append(contentsOf: partyEvents)
            return EffectApplyOutcome(events: events, didApply: !partyEvents.isEmpty)
        }
        context.roster.setActiveEffects(currentEffects, for: target)
        var events = CombatTriggerEngine.afterHeroCleanse(source: source, target: target, removed: [keyword], in: &context)
        events.append(context.nextEvent(
            kind: .effect,
            effectKind: .cleanseApplied,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: 0,
            keyword: keyword,
        ))
        events.append(contentsOf: CombatTriggerEngine.healAfterCleanse(source: source, target: target, in: &context).events)
        events.append(contentsOf: CombatTriggerEngine.healWearerAfterCleanse(source: source, in: &context).events)
        events.append(contentsOf: CombatTriggerEngine.drawAfterCleanse(source: source, in: &context))
        events.append(contentsOf: CombatTriggerEngine.afterCleansePerformed(
            source: source,
            target: target,
            removedKeyword: keyword,
            removedCount: 1,
            in: &context,
        ))
        return EffectApplyOutcome(events: events, didApply: true)
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
        let removed = EffectRemoval.removeBuffs(from: &currentEffects, keyword: targetKeyword)
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
        )
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
        guard let keyword = EffectRemoval.removeRandomBuff(from: &currentEffects, using: &context.rng) else {
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
            keyword: keyword,
        )
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
