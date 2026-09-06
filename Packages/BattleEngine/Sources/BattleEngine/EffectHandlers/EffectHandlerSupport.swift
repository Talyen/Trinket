import Foundation
import TrinketContent
import TrinketCore

enum EffectRemoval {
    @discardableResult
    static func removeDebuffs(from effects: inout [ActiveEffect], keyword: Keyword?) -> [ActiveEffect] {
        removeMatching(from: &effects, keyword: keyword) { $0.effect.isRemovableDebuff }
    }

    static func removeRandomDebuff(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
    ) -> Keyword? {
        removeRandom(from: &effects, using: &rng) { $0.effect.isRemovableDebuff }
    }

    @discardableResult
    static func removeBuffs(from effects: inout [ActiveEffect], keyword: Keyword?) -> [ActiveEffect] {
        removeMatching(from: &effects, keyword: keyword) { $0.effect.isRemovableBuff }
    }

    static func removeRandomBuff(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
    ) -> Keyword? {
        removeRandom(from: &effects, using: &rng) { $0.effect.isRemovableBuff }
    }

    static func removeBuffs(
        from effects: inout [ActiveEffect],
        count: Int,
        removeAll: Bool,
        using rng: inout SeededRandomNumberGenerator,
    ) -> [Keyword] {
        if removeAll {
            return removeBuffs(from: &effects, keyword: nil).map(\.keyword)
        }

        var removed: [Keyword] = []
        for _ in 0 ..< count {
            guard let keyword = removeRandomBuff(from: &effects, using: &rng) else { break }
            removed.append(keyword)
        }
        return removed
    }

    @discardableResult
    private static func removeMatching(
        from effects: inout [ActiveEffect],
        keyword: Keyword?,
        where matches: (ActiveEffect) -> Bool,
    ) -> [ActiveEffect] {
        var removed: [ActiveEffect] = []
        var remaining: [ActiveEffect] = []
        for effect in effects {
            let isMatch = matches(effect) && (keyword == nil || effect.keyword == keyword)
            if isMatch {
                removed.append(effect)
            } else {
                remaining.append(effect)
            }
        }
        effects = remaining
        return removed
    }

    private static func removeRandom(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
        where matches: (ActiveEffect) -> Bool,
    ) -> Keyword? {
        let candidates = effects.filter(matches)
        guard let removed = candidates.randomElement(using: &rng) else { return nil }
        effects.removeAll { $0.id == removed.id }
        return removed.keyword
    }
}

enum TimedBuffSummary {
    static func minRemainingTurns(in stacks: [ActiveEffect], duration: (Effect) -> Int?) -> Int {
        stacks.compactMap { active -> Int? in
            guard let baseDuration = duration(active.effect) else { return nil }
            return active.remainingTurns > 0 ? active.remainingTurns : baseDuration
        }.min() ?? 0
    }
}

enum CleanseEventBuilder {
    static func events(
        removed: [ActiveEffect],
        abilityName: String,
        source: Combatant,
        target: Combatant,
        healAmount: Int? = nil,
        healTarget: Combatant? = nil,
        in context: inout BattleState,
    ) -> [ActionEvent] {
        var countsByKeyword: [Keyword: Int] = [:]
        for item in removed {
            countsByKeyword[item.keyword, default: 0] += 1
        }
        var events = CombatTriggerEngine.afterHeroCleanse(
            source: source, target: target, removed: removed.map(\.keyword), in: &context,
        )
        for (keyword, _) in countsByKeyword.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            events.append(context.nextEvent(
                kind: .effect,
                effectKind: .cleanseApplied,
                actorName: source.name,
                abilityName: abilityName,
                target: target,
                amount: 0,
                keyword: keyword,
            ))
        }
        if let healAmount, let healTarget, healAmount > 0 {
            events.append(contentsOf: context.healEmitting(
                amount: healAmount,
                target: healTarget,
                source: source,
                abilityName: abilityName,
                isDirectCardHeal: context.hasHeroCard(for: source.id),
            ))
        }
        events.append(contentsOf: CombatTriggerEngine.healAfterCleanse(source: source, target: target, in: &context).events)
        events.append(contentsOf: CombatTriggerEngine.healWearerAfterCleanse(source: source, in: &context).events)
        events.append(contentsOf: CombatTriggerEngine.drawAfterCleanse(source: source, in: &context))
        events.append(contentsOf: CombatTriggerEngine.afterCleanseAction(
            source: source,
            target: target,
            removedCount: removed.count,
            in: &context,
        ))
        for (keyword, count) in countsByKeyword.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            events.append(contentsOf: CombatTriggerEngine.afterCleanseKeywordReaction(
                source: source,
                removedKeyword: keyword,
                removedCount: count,
                in: &context,
            ))
        }
        return events
    }
}

enum ActiveEffectMutation {
    static func removeMatching(
        from target: Combatant,
        in context: inout BattleState,
        where matches: (Effect) -> Bool,
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll { matches($0.effect) }
        context.roster.setActiveEffects(effects, for: target)
    }

    static func replaceAndEmit(
        _ effect: Effect,
        to target: Combatant,
        source: Combatant,
        ability: Ability,
        in context: inout BattleState,
        replacing matches: (Effect) -> Bool,
        event: (kind: ActionEvent.EffectOutcome, amount: Int, keyword: Keyword),
    ) -> ActionEvent {
        removeMatching(from: target, in: &context, where: matches)
        context.appendEffect(effect, to: target, sourceID: source.id, remainingTurns: effect.durationTurns)
        return context.nextEvent(
            kind: .effect,
            effectKind: event.kind,
            actorName: source.name,
            abilityName: ability.name,
            target: target,
            amount: event.amount,
            keyword: event.keyword,
        )
    }
}
