import Foundation
import TrinketContent
import TrinketCore

enum EffectRemoval {
    @discardableResult
    static func removeDebuffs(from effects: inout [ActiveEffect], keyword: Keyword?) -> Bool {
        removeMatching(from: &effects, keyword: keyword) { $0.effect.isRemovableDebuff }
    }

    static func removeRandomDebuff(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator
    ) -> Keyword? {
        removeRandom(from: &effects, using: &rng) { $0.effect.isRemovableDebuff }
    }

    @discardableResult
    static func removeBuffs(from effects: inout [ActiveEffect], keyword: Keyword?) -> Bool {
        removeMatching(from: &effects, keyword: keyword) { $0.effect.isRemovableBuff }
    }

    static func removeRandomBuff(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator
    ) -> Keyword? {
        removeRandom(from: &effects, using: &rng) { $0.effect.isRemovableBuff }
    }

    @discardableResult
    private static func removeMatching(
        from effects: inout [ActiveEffect],
        keyword: Keyword?,
        where matches: (ActiveEffect) -> Bool
    ) -> Bool {
        let before = effects.count
        if let keyword {
            effects.removeAll { $0.keyword == keyword && matches($0) }
        } else {
            effects.removeAll(where: matches)
        }
        return effects.count < before
    }

    private static func removeRandom(
        from effects: inout [ActiveEffect],
        using rng: inout SeededRandomNumberGenerator,
        where matches: (ActiveEffect) -> Bool
    ) -> Keyword? {
        let candidates = effects.filter(matches)
        guard let removed = candidates.randomElement(using: &rng) else { return nil }
        effects.removeAll { $0.id == removed.id }
        return removed.keyword
    }
}

enum TimedBuffSummary {
    static func minRemainingTicks(in stacks: [ActiveEffect], duration: (Effect) -> Int?) -> Int {
        stacks.compactMap { active -> Int? in
            guard let baseDuration = duration(active.effect) else { return nil }
            return active.remainingTicks > 0 ? active.remainingTicks : baseDuration
        }.min() ?? 0
    }
}

enum ActiveEffectMutation {
    /// Drops every active effect on `target` whose `Effect` matches `matches`.
    static func removeMatching(
        from target: Combatant,
        in context: inout BattleEngineContext,
        where matches: (Effect) -> Bool
    ) {
        var effects = context.roster.activeEffects(for: target)
        effects.removeAll { matches($0.effect) }
        context.roster.setActiveEffects(effects, for: target)
    }
}
